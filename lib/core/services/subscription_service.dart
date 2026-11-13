import 'package:drift/drift.dart';

import 'package:craft_pos/core/database/app_database.dart';
import 'package:craft_pos/core/models/subscription_model.dart';

class SubscriptionService {
  final AppDatabase db;
  SubscriptionService(this.db);

  // ═══ READS ═══

  /// Active subscription (if any). Returns null when on free trial.
  Future<SubscriptionModel?> getActive() async {
    final now = DateTime.now();
    final rows = await (db.select(db.subscriptions)
      ..where((t) =>
      t.active.equals(true) & t.expiresAt.isBiggerThanValue(now))
      ..orderBy([(t) => OrderingTerm.desc(t.expiresAt)])
      ..limit(1))
        .get();
    if (rows.isEmpty) return null;
    return SubscriptionModel.fromRow(rows.first);
  }

  /// Full state — active plan + recent payment attempts.
  /// Used by the UI and by the reconciliation job.
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

  // ═══ WRITES ═══

  Future<SubscriptionModel> activate({
    required String plan,
    required String source,
  }) async {
    final now = DateTime.now();
    final duration = switch (plan) {
      'weekly' => const Duration(days: 7),
      'monthly' => const Duration(days: 30),
      'yearly' => const Duration(days: 365),
      _ => const Duration(days: 30),
    };

    // Deactivate any existing active row before inserting the new one.
    // (SQLite has no partial unique index in our schema, so do it manually.)
    await (db.update(db.subscriptions)..where((t) => t.active.equals(true)))
        .write(const SubscriptionsCompanion(active: Value(false)));

    final id = await db.into(db.subscriptions).insert(
      SubscriptionsCompanion.insert(
        plan: plan,
        startedAt: now,
        expiresAt: now.add(duration),
        source: source,
      ),
    );

    final row = await (db.select(db.subscriptions)
      ..where((t) => t.id.equals(id)))
        .getSingle();

    return SubscriptionModel.fromRow(row);
  }

  Future<void> recordAttempt({
    required String checkoutRequestId,
    required int amount,
    required String plan,
    required String phone,
    required String state,
    String? receipt,
    String? message,
  }) async {
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
    );
  }

  /// Update a previously-recorded attempt (used by the reconciliation job).
  Future<void> resolveAttempt({
    required int attemptId,
    required String state,
    String? receipt,
    String? message,
  }) async {
    await (db.update(db.paymentAttempts)
      ..where((t) => t.id.equals(attemptId)))
        .write(
      PaymentAttemptsCompanion(
        state: Value(state),
        receipt: Value(receipt),
        message: Value(message),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }
}