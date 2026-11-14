import 'dart:async';
// lib/core/services/subscription_service.dart

import 'package:drift/drift.dart';
import 'package:craft_pos/core/database/app_database.dart';
import 'package:craft_pos/core/models/subscription_model.dart';

class SubscriptionService {
  final AppDatabase db;
  SubscriptionService(this.db);

  // ═══════════════════════════════════════════════════════════════
  // READS
  // ═══════════════════════════════════════════════════════════════

  /// Active subscription (if any). Returns null when on free trial.
  Future<SubscriptionModel?> getActive() async {
    final now = DateTime.now();
    final rows = await (db.select(db.subscriptions)
      ..where((t) => t.active.equals(true) & t.expiresAt.isBiggerThanValue(now))
      ..orderBy([(t) => OrderingTerm.desc(t.expiresAt)])
      ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    return SubscriptionModel.fromRow(rows.first);
  }

  /// Streams the active subscription — for UI banner + guards.
  Stream<SubscriptionModel?> watchActive() {
    final now = DateTime.now();
    return (db.select(db.subscriptions)
      ..where((t) => t.active.equals(true) & t.expiresAt.isBiggerThanValue(now))
      ..orderBy([(t) => OrderingTerm.desc(t.expiresAt)])
      ..limit(1))
        .watchSingleOrNull()
        .map((row) => row == null ? null : SubscriptionModel.fromRow(row));
  }

  /// Full state — active plan + recent attempts. Use in `StreamBuilder`.
  ///
  /// ⭐ Emits whenever either `subscriptions` or `payment_attempts` changes,
  /// because Drift tracks both tables via `readsFrom`.
  Stream<SubscriptionState> watchFullState({int attemptsLimit = 20}) {
    // Watch attempts (always present — one row exists per attempt ever made).
    final attemptsStream = (db.select(db.paymentAttempts)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(attemptsLimit))
        .watch();

    // Watch active subscription.
    final activeStream = watchActive();

    // Merge: emit a new SubscriptionState whenever either side emits.
    return _combineLatest2(
      attemptsStream,
      activeStream,
          (List<PaymentAttemptRow> rows, SubscriptionModel? active) {
        return SubscriptionState(
          active: active,
          recentAttempts:
          rows.map(PaymentAttempt.fromRow).toList(growable: false),
        );
      },
    );
  }

  /// Snapshot of the full state.
  Future<SubscriptionState> loadFullState({int attemptsLimit = 20}) async {
    final active = await getActive();
    final attemptRows = await (db.select(db.paymentAttempts)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(attemptsLimit))
        .get();

    return SubscriptionState(
      active: active,
      recentAttempts:
      attemptRows.map(PaymentAttempt.fromRow).toList(growable: false),
    );
  }

  /// The pending attempt, if any. Single source of truth for the double-charge guard.
  Future<PaymentAttempt?> getPendingAttempt() async {
    final row = await (db.select(db.paymentAttempts)
      ..where((t) => t.state.equals(PaymentAttemptState.pending))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1))
        .getSingleOrNull();
    return row == null ? null : PaymentAttempt.fromRow(row);
  }

  // ═══════════════════════════════════════════════════════════════
  // WRITES — attempts
  // ═══════════════════════════════════════════════════════════════

  /// Start a new payment attempt. **This is what the UI must call.**
  ///
  /// Returns `null` if the double-charge guard trips (a pending attempt
  /// already exists). Returns the (existing or new) attempt otherwise.
  ///
  /// Pass `checkoutRequestId` only when the STK push has already been
  /// initiated externally (e.g. server-side). When the UI initiates the
  /// push itself, leave it `null` here and pass it back via
  /// [recordAttempt] once the gateway responds.
  Future<PaymentAttempt?> startAttempt({
    required int amount,
    required String plan,
    required String phone,
    String? checkoutRequestId,
  }) async {
    // ⭐ Transactional guard: the "check pending → insert" sequence must be
    // atomic, otherwise two fast taps can both pass the check.
    return db.transaction(() async {
      // Guard 1: refuse if any pending attempt exists.
      final pending = await getPendingAttempt();
      if (pending != null) return null;

      // Guard 2: if a checkoutRequestId is supplied and already exists,
      // return the existing row — do not create a duplicate.
      if (checkoutRequestId != null) {
        final existing = await (db.select(db.paymentAttempts)
          ..where((t) => t.checkoutRequestId.equals(checkoutRequestId)))
            .getSingleOrNull();
        if (existing != null) return PaymentAttempt.fromRow(existing);
      }

      await db.into(db.paymentAttempts).insert(
        PaymentAttemptsCompanion.insert(
          checkoutRequestId: Value(checkoutRequestId),
          amount: amount,
          plan: plan,
          phone: phone,
          state: PaymentAttemptState.pending,
        ),
      );

      // Read back the row we just inserted (still inside the transaction).
      final inserted = await (db.select(db.paymentAttempts)
        ..where((t) => t.state.equals(PaymentAttemptState.pending))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
        ..limit(1))
          .getSingle();
      return PaymentAttempt.fromRow(inserted);
    });
  }

  /// Upsert a payment attempt by `checkoutRequestId`.
  ///
  /// Safe for Safaricom callback retries — if a row with the same
  /// `checkoutRequestId` already exists, it is updated (state kept
  /// monotonic: success/failed are terminal, only pending→other).
  ///
  /// Returns the resulting attempt, or `null` if the callback referenced
  /// an unknown attempt and `createIfMissing == false`.
  Future<PaymentAttempt?> recordAttempt({
    required String checkoutRequestId,
    required int amount,
    required String plan,
    required String phone,
    required String state,
    String? receipt,
    String? message,
    bool createIfMissing = true,
  }) async {
    final existingRow = await (db.select(db.paymentAttempts)
      ..where((t) => t.checkoutRequestId.equals(checkoutRequestId)))
        .getSingleOrNull();

    // ── Case 1: no prior attempt ─────────────────────────────────────
    if (existingRow == null) {
      if (!createIfMissing) return null;

      // Unique index on checkout_request_id protects against concurrent
      // inserts from a double-delivered callback.
      await db.into(db.paymentAttempts).insert(
        PaymentAttemptsCompanion.insert(
          checkoutRequestId: Value(checkoutRequestId),
          amount: amount,
          plan: plan,
          phone: phone,
          state: state,
          receipt: Value(receipt),
          message: Value(message),
          resolvedAt: Value(
            state == PaymentAttemptState.pending ? null : DateTime.now(),
          ),
        ),
        mode: InsertMode.insertOrIgnore,
      );

      final row = await (db.select(db.paymentAttempts)
        ..where((t) => t.checkoutRequestId.equals(checkoutRequestId)))
          .getSingle();
      return PaymentAttempt.fromRow(row);
    }

    // ── Case 2: prior attempt exists — monotonic transition ──────────
    final current = PaymentAttempt.fromRow(existingRow);
    if (current.isSuccess || current.isFailed) {
      return current; // already terminal, ignore late retries
    }

    return _applyTerminalTransition(
      current: current,
      state: state,
      receipt: receipt,
      message: message,
    );
  }

  /// Resolve a previously-recorded attempt. Idempotent — skips terminal states.
  /// On success, activates the subscription in the same transaction.
  Future<void> resolveAttempt({
    required int attemptId,
    required String state,
    String? receipt,
    String? message,
  }) async {
    final row = await (db.select(db.paymentAttempts)
      ..where((t) => t.id.equals(attemptId)))
        .getSingleOrNull();
    if (row == null) return;

    final current = PaymentAttempt.fromRow(row);
    if (current.isSuccess || current.isFailed) {
      return; // terminal — do nothing
    }

    await _applyTerminalTransition(
      current: current,
      state: state,
      receipt: receipt,
      message: message,
    );
  }

  /// ⭐ Shared terminal-transition logic used by both `recordAttempt` and
  /// `resolveAttempt`. Wrapped in a transaction so the attempt write and the
  /// subscription activation are atomic.
  ///
  /// Preconditions: `current` is NOT already in a terminal state.
  Future<PaymentAttempt> _applyTerminalTransition({
    required PaymentAttempt current,
    required String state,
    String? receipt,
    String? message,
  }) async {
    assert(
    !current.isSuccess && !current.isFailed,
    'Cannot transition a terminal attempt',
    );

    return db.transaction(() async {
      await (db.update(db.paymentAttempts)
        ..where((t) => t.id.equals(current.id)))
          .write(
        PaymentAttemptsCompanion(
          state: Value(state),
          receipt: Value(receipt),
          message: Value(message),
          resolvedAt: Value(
            state == PaymentAttemptState.pending ? null : DateTime.now(),
          ),
        ),
      );

      if (state == PaymentAttemptState.success) {
        await _activateFromAttempt(current);
      }

      final updatedRow = await (db.select(db.paymentAttempts)
        ..where((t) => t.id.equals(current.id)))
          .getSingle();
      return PaymentAttempt.fromRow(updatedRow);
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // WRITES — activation (private; only callable from the callback path)
  // ═══════════════════════════════════════════════════════════════

  /// Activates a subscription tied to a specific attempt. Idempotent.
  /// **Only** call from `_applyTerminalTransition` on success.
  ///
  /// Idempotency key: `(attempt.createdAt, plan duration)` — if an active
  /// subscription already exists with this exact window, it's returned
  /// unchanged, so a duplicate callback cannot extend the plan twice.
  Future<SubscriptionModel> _activateFromAttempt(PaymentAttempt attempt) async {
    // Use the attempt's creation time as the subscription start, so the
    // subscription window is stable across retries.
    final startedAt = attempt.createdAt;
    final expiresAt = startedAt.add(_planDuration(attempt.plan));

    // If a subscription already exists with this exact window, return it.
    final existing = await (db.select(db.subscriptions)
      ..where((t) => t.active.equals(true))
      ..where((t) => t.startedAt.equals(startedAt))
      ..where((t) => t.expiresAt.equals(expiresAt))
      ..limit(1))
        .getSingleOrNull();
    if (existing != null) return SubscriptionModel.fromRow(existing);

    // Atomic swap: deactivate all → insert new. The partial unique index
    // `idx_one_active_subscription` in `beforeOpen` enforces at most one
    // active row even under concurrent activation attempts.
    return db.transaction(() async {
      await (db.update(db.subscriptions)..where((t) => t.active.equals(true)))
          .write(const SubscriptionsCompanion(active: Value(false)));

      final id = await db.into(db.subscriptions).insert(
        SubscriptionsCompanion.insert(
          plan: attempt.plan,
          startedAt: startedAt,
          expiresAt: expiresAt,
          source: 'mpesa',
        ),
      );

      final row = await (db.select(db.subscriptions)
        ..where((t) => t.id.equals(id)))
          .getSingle();
      return SubscriptionModel.fromRow(row);
    });
  }

  Duration _planDuration(String plan) => switch (plan) {
    'weekly' => const Duration(days: 7),
    'monthly' => const Duration(days: 30),
    'yearly' => const Duration(days: 365),
    _ => const Duration(days: 30),
  };

  // ═══════════════════════════════════════════════════════════════
  // Manual activation (activation code path only — not payment)
  // ═══════════════════════════════════════════════════════════════

  /// Activate via an external source (e.g. an activation code, an admin
  /// grant). **Do not** use this from the M-Pesa flow — that goes through
  /// `_activateFromAttempt` so it's tied to a payment.
  Future<SubscriptionModel> activateExternal({
    required String plan,
    required String source,
  }) async {
    final now = DateTime.now();
    final expiresAt = now.add(_planDuration(plan));

    return db.transaction(() async {
      await (db.update(db.subscriptions)..where((t) => t.active.equals(true)))
          .write(const SubscriptionsCompanion(active: Value(false)));

      final id = await db.into(db.subscriptions).insert(
        SubscriptionsCompanion.insert(
          plan: plan,
          startedAt: now,
          expiresAt: expiresAt,
          source: source,
        ),
      );

      final row = await (db.select(db.subscriptions)
        ..where((t) => t.id.equals(id)))
          .getSingle();
      return SubscriptionModel.fromRow(row);
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // INTERNAL — stream combining
  // ═══════════════════════════════════════════════════════════════

  /// Minimal 2-stream combiner without pulling in `rxdart`.
  Stream<R> _combineLatest2<A, B, R>(
      Stream<A> a,
      Stream<B> b,
      R Function(A, B) combine,
      ) {
    late A latestA;
    late B latestB;
    var hasA = false;
    var hasB = false;

    final controller = StreamController<R>();
    late StreamSubscription<A> subA;
    late StreamSubscription<B> subB;

    void emit() {
      if (hasA && hasB) controller.add(combine(latestA, latestB));
    }

    controller.onListen = () {
      subA = a.listen(
            (v) {
          latestA = v;
          hasA = true;
          emit();
        },
        onError: controller.addError,
        onDone: () {
          if (hasB) controller.close();
        },
      );
      subB = b.listen(
            (v) {
          latestB = v;
          hasB = true;
          emit();
        },
        onError: controller.addError,
        onDone: () {
          if (hasA) controller.close();
        },
      );
    };

    controller.onCancel = () async {
      await subA.cancel();
      await subB.cancel();
    };

    return controller.stream;
  }
}