// lib/core/services/mpesa/mpesa_models.dart

// ═══════════════════════════════════════════════════════════════════
// PAYMENT STATE
// ═══════════════════════════════════════════════════════════════════

/// Lifecycle states emitted by `MpesaService.pay(...)`.
///
/// Terminal states (for the `pay()` stream): [success], [failed], [timeout].
/// Note: `timeout` is *terminal for the stream* but **not** terminal for
/// `SubscriptionReconcileService` — a late M-Pesa callback can still flip a
/// timed-out attempt to success. See `PaymentAttempt.isResolved` for the
/// attempt-level terminal check.
enum PaymentState { idle, initiating, awaitingPin, success, failed, timeout }

// ═══════════════════════════════════════════════════════════════════
// STK PUSH — initiate response
// ═══════════════════════════════════════════════════════════════════

/// The simplified response from the Next.js backend when initiating STK Push.
class StkPushResponse {
  final String checkoutRequestId;
  final String customerMessage;

  const StkPushResponse({
    required this.checkoutRequestId,
    required this.customerMessage,
  });

  factory StkPushResponse.fromJson(Map<String, dynamic> j) => StkPushResponse(
    checkoutRequestId: j['checkoutRequestId'] as String? ?? '',
    customerMessage: j['customerMessage'] as String? ?? '',
  );

  @override
  String toString() =>
      'StkPushResponse(checkoutRequestId: $checkoutRequestId)';
}

// ═══════════════════════════════════════════════════════════════════
// STK QUERY — reconcile response
// ═══════════════════════════════════════════════════════════════════

/// Allowed values for [MpesaStkQueryResult.state].
///
/// Using constants rather than a Dart enum keeps the reconciler's
/// `switch (status.state)` on plain strings compilable, while giving
/// callers a compile-time typo check via these constants.
class MpesaStkQueryState {
  static const success = 'success';
  static const failed = 'failed';
  static const pending = 'pending';

  /// All three states, for assertions / exhaustive checks.
  static const all = <String>{success, failed, pending};
}

/// Result of a status query against the backend's `/api/mpesa/status/:id`
/// endpoint. Consumed by `SubscriptionReconcileService` when a pending
/// attempt has gone stale.
class MpesaStkQueryResult {
  /// One of [MpesaStkQueryState.success], [MpesaStkQueryState.failed],
  /// or [MpesaStkQueryState.pending].
  final String state;

  /// M-Pesa receipt. May be null even on `success` if the backend hasn't
  /// received the callback yet — the callback later backfills it.
  final String? receipt;

  /// Human-readable description from the backend / Safaricom.
  final String? message;

  const MpesaStkQueryResult({
    required this.state,
    this.receipt,
    this.message,
  });

  bool get isSuccess => state == MpesaStkQueryState.success;
  bool get isFailed => state == MpesaStkQueryState.failed;
  bool get isPending => state == MpesaStkQueryState.pending;

  @override
  String toString() =>
      'MpesaStkQueryResult(state: $state, receipt: $receipt, message: $message)';
}

// ═══════════════════════════════════════════════════════════════════
// PAYMENT STATUS — emitted by the pay() stream
// ═══════════════════════════════════════════════════════════════════

/// A single tick of the `MpesaService.pay(...)` stream.
class PaymentStatus {
  final PaymentState state;
  final String? receipt;
  final String? message;
  final String? checkoutRequestId;

  const PaymentStatus({
    required this.state,
    this.receipt,
    this.message,
    this.checkoutRequestId,
  });

  static const idle = PaymentStatus(state: PaymentState.idle);

  /// Build from the backend's `/api/mpesa/status/:id` response.
  ///
  /// Backend statuses are uppercase: `PENDING`, `SUCCESS`, `FAILED`, `TIMEOUT`.
  /// Anything unrecognised is treated as `FAILED` to be safe — we don't want
  /// a typo on the backend side silently keeping a sale in `PENDING` forever.
  factory PaymentStatus.fromJson(
      Map<String, dynamic> j, {
        required String checkoutRequestId,
      }) {
    final status = (j['status'] as String?)?.toUpperCase() ?? '';
    final receipt = j['receipt'] as String?;
    final resultDesc = j['resultDesc'] as String?;

    switch (status) {
      case 'SUCCESS':
        return PaymentStatus(
          state: PaymentState.success,
          receipt: receipt,
          message: resultDesc ?? 'Payment successful',
          checkoutRequestId: checkoutRequestId,
        );

      case 'PENDING':
        return PaymentStatus(
          state: PaymentState.awaitingPin,
          checkoutRequestId: checkoutRequestId,
        );

      case 'TIMEOUT':
        return PaymentStatus(
          state: PaymentState.timeout,
          checkoutRequestId: checkoutRequestId,
          message: resultDesc ??
              'Payment status unknown. Check your M-Pesa SMS.',
        );

      case 'FAILED':
      default:
        return PaymentStatus(
          state: PaymentState.failed,
          checkoutRequestId: checkoutRequestId,
          message: resultDesc ?? 'Payment was not completed.',
        );
    }
  }

  /// Terminal **for the `pay()` stream** — no further events will be emitted
  /// once one of these states is yielded.
  ///
  /// ⚠️ `timeout` is NOT terminal for `SubscriptionReconcileService`:
  /// a late callback can still flip a timed-out attempt to `success`.
  /// Use `PaymentAttempt.isResolved` for the persistence-level check.
  bool get isTerminal =>
      state == PaymentState.success ||
          state == PaymentState.failed ||
          state == PaymentState.timeout;

  bool get isSuccess => state == PaymentState.success;
  bool get isFailure =>
      state == PaymentState.failed || state == PaymentState.timeout;
  bool get isPending =>
      state == PaymentState.initiating ||
          state == PaymentState.awaitingPin;

  @override
  String toString() =>
      'PaymentStatus(state: $state, receipt: $receipt, message: $message)';
}