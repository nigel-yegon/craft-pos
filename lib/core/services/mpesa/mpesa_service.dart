import 'dart:async';
import '../connectivity_service.dart';
import 'mpesa_config.dart';
import 'mpesa_models.dart';
import 'mpesa_query.dart';
import 'mpesa_stk_push.dart';

/// High-level M-Pesa service.
///
/// OFFLINE BEHAVIOR:
/// - If offline, `pay()` immediately returns a `failed` status with
///   message "You are offline. M-Pesa requires internet."
/// - No network call is made while offline.
class MpesaService {
  final MpesaConfig config;
  final ConnectivityService _connectivity;
  late final MpesaStkPush _stk;
  late final MpesaQuery _query;

  MpesaService(this.config, this._connectivity) {
    _stk = MpesaStkPush(config);
    _query = MpesaQuery(config, _stk.auth);
  }

  /// Normalize Kenyan phone to 2547XXXXXXXX.
  /// Accepts: 0712..., 712..., +254712..., 254712...
  static String normalizePhone(String input) {
    var p = input.replaceAll(RegExp(r'\s+'), '');
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('0')) return '254${p.substring(1)}';
    if (p.startsWith('254')) return p;
    if (p.startsWith('7') && p.length == 9) return '254$p';
    if (p.startsWith('1') && p.length == 9) return '254$p';
    return p;
  }

  /// Initiate STK Push and then poll status until success/fail/timeout.
  ///
  /// Emits progressive states so the UI can show "check your phone" etc.
  Stream<PaymentStatus> pay({
    required String phone,
    required int amount,
    required String accountRef,
    required String description,
  }) async* {
    // 1. Offline gate
    if (!_connectivity.isOnline) {
      yield const PaymentStatus(
        state: PaymentState.failed,
        message: 'You are offline. M-Pesa requires an internet connection.',
      );
      return;
    }

    final normalized = normalizePhone(phone);
    if (!RegExp(r'^254(7|1)\d{8}$').hasMatch(normalized)) {
      yield const PaymentStatus(
        state: PaymentState.failed,
        message: 'Invalid phone number. Use 07XX XXX XXX or 01XX XXX XXX.',
      );
      return;
    }

    yield const PaymentStatus(state: PaymentState.initiating);

    StkPushResult push;
    try {
      push = await _stk.initiate(
        phone: normalized,
        amount: amount,
        accountRef: accountRef,
        description: description,
      );
    } catch (e) {
      yield PaymentStatus(
        state: PaymentState.failed,
        message: 'Could not reach M-Pesa: $e',
      );
      return;
    }

    if (push.responseCode != '0') {
      yield PaymentStatus(
        state: PaymentState.failed,
        message: push.customerMessage.isNotEmpty
            ? push.customerMessage
            : 'M-Pesa rejected the request.',
      );
      return;
    }

    yield PaymentStatus(
      state: PaymentState.awaitingPin,
      checkoutRequestId: push.checkoutRequestId,
      message: push.customerMessage,
    );

    // 2. Poll stkQuery until final result (max ~90s, 3s interval)
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 3));
      if (!_connectivity.isOnline) {
        // Connectivity lost mid-poll. Do NOT report failure.
        // Money may have been taken.
        yield PaymentStatus(
          state: PaymentState.timeout,
          checkoutRequestId: push.checkoutRequestId,
          message:
          'Lost connection while checking payment. If you received an M-Pesa SMS, payment succeeded — otherwise retry later.',
        );
        return;
      }
      try {
        final q = await _query.query(push.checkoutRequestId);
        final code = '${q['ResultCode'] ?? ''}';
        final desc = q['ResultDesc']?.toString() ?? '';

        if (code == '0') {
          // Success — receipt is in CallbackMetadata but stkQuery usually
          // does not include it; we still confirm success.
          yield PaymentStatus(
            state: PaymentState.success,
            checkoutRequestId: push.checkoutRequestId,
            message: desc.isNotEmpty ? desc : 'Payment successful',
          );
          return;
        }

        // In-progress codes: 1037 = timeout on Safaricom side,
        // 4999 = still processing. Anything else is final.
        if (code == '1037' || code == '4999') {
          continue; // keep polling until deadline
        }

        // Final failure
        yield PaymentStatus(
          state: PaymentState.failed,
          checkoutRequestId: push.checkoutRequestId,
          message: desc.isNotEmpty ? desc : 'Payment was not completed.',
        );
        return;
      } catch (_) {
        // Network blip — keep polling
        continue;
      }
    }

    // Ran out of time without a definitive answer
    yield PaymentStatus(
      state: PaymentState.timeout,
      checkoutRequestId: push.checkoutRequestId,
      message:
      'Still waiting on M-Pesa. If you got an SMS confirmation, it succeeded.',
    );
  }
}