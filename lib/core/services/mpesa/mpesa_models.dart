// lib/core/services/mpesa/mpesa_models.dart

enum PaymentState { idle, initiating, awaitingPin, success, failed, timeout }

/// The simplified response from our Next.js backend when initiating STK Push.
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
}

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

  /// Build from our Next.js backend's `/api/mpesa/status/:id` response.
  factory PaymentStatus.fromJson(
      Map<String, dynamic> j, {
        required String checkoutRequestId,
      }) {
    // The backend returns uppercase statuses: PENDING, SUCCESS, FAILED, TIMEOUT
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

  bool get isTerminal =>
      state == PaymentState.success ||
          state == PaymentState.failed ||
          state == PaymentState.timeout;
}