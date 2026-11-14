// lib/core/services/subscription_reconcile_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:craft_pos/core/database/app_database.dart';
import 'package:craft_pos/core/models/subscription_model.dart';
import 'package:craft_pos/core/services/mpesa/mpesa_service.dart'; // ← your STK query-status client
import 'package:craft_pos/core/services/subscription_service.dart';

class SubscriptionReconcileService {
  final AppDatabase db;
  final SubscriptionService subs;
  final MpesaService mpesa;

  /// Attempts older than this with no terminal state are queried against
  /// M-Pesa. Below this, we trust the callback to arrive.
  static const staleThreshold = Duration(minutes: 2);

  /// Attempts older than this are marked timeout without querying (M-Pesa
  /// no longer knows about them).
  static const abandonThreshold = Duration(hours: 24);

  Timer? _timer;
  bool _running = false;

  SubscriptionReconcileService({
    required this.db,
    required this.subs,
    required this.mpesa,
  });

  /// Start a periodic reconciliation while the app is alive.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => tick());
    tick(); // immediate first pass
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// App lifecycle callback — call on `AppLifecycleState.resumed`.
  Future<void> onResume() => tick();

  /// One reconciliation pass. Concurrency-safe: no overlapping passes.
  Future<void> tick() async {
    if (_running) return;
    _running = true;
    try {
      await _reconcilePending();
    } catch (e, st) {
      debugPrint('Reconcile error: $e\n$st');
    } finally {
      _running = false;
    }
  }

  Future<void> _reconcilePending() async {
    final now = DateTime.now();

    final rows = await (db.select(db.paymentAttempts)
      ..where((t) => t.state.equals(PaymentAttemptState.pending)))
        .get();

    for (final row in rows) {
      final attempt = PaymentAttempt.fromRow(row);
      final age = now.difference(attempt.createdAt);

      // Too old — give up, mark timeout (user wasn't charged or was refunded).
      if (age > abandonThreshold) {
        await subs.resolveAttempt(
          attemptId: attempt.id,
          state: PaymentAttemptState.timeout,
          message: 'No callback received within 24h',
        );
        continue;
      }

      // Not stale yet — let the callback arrive.
      if (age < staleThreshold) continue;

      // Ask M-Pesa what happened.
      if (attempt.checkoutRequestId == null) {
        await subs.resolveAttempt(
          attemptId: attempt.id,
          state: PaymentAttemptState.timeout,
          message: 'No checkout request id',
        );
        continue;
      }

      try {
        final status = await mpesa.queryStkStatus(
          checkoutRequestId: attempt.checkoutRequestId!,
        );

        switch (status.state) {
          case 'success':
            await subs.resolveAttempt(
              attemptId: attempt.id,
              state: PaymentAttemptState.success,
              receipt: status.receipt,
              message: status.message,
            );
            break;
          case 'failed':
            await subs.resolveAttempt(
              attemptId: attempt.id,
              state: PaymentAttemptState.failed,
              receipt: status.receipt,
              message: status.message,
            );
            break;
          default:
          // Still pending on M-Pesa's side — wait another pass.
            break;
        }
      } catch (e) {
        debugPrint('STK query error for attempt ${attempt.id}: $e');
      }
    }
  }
}