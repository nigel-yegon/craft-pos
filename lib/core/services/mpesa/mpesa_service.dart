// lib/core/services/mpesa/mpesa_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:craft_pos/core/services/connectivity_service.dart';
import 'package:craft_pos/core/services/mpesa/mpesa_config.dart';
import 'package:craft_pos/core/services/mpesa/mpesa_models.dart';

class MpesaService {
  final MpesaConfig config;
  final ConnectivityService connectivity;
  final http.Client _http;

  MpesaService(this.config, this.connectivity, {http.Client? client})
      : _http = client ?? http.Client();

  static String normalizePhone(String input) {
    var p = input.replaceAll(RegExp(r'\s+'), '');
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('0')) return '254${p.substring(1)}';
    if (p.startsWith('254')) return p;
    if (p.startsWith('7') && p.length == 9) return '254$p';
    if (p.startsWith('1') && p.length == 9) return '254$p';
    return p;
  }

  Stream<PaymentStatus> pay({
    required String phone,
    required int amount,
    required String accountRef,
    required String description,
    required String plan,
  }) async* {
    if (!connectivity.isOnline) {
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

    StkPushResponse push;
    try {
      final res = await _http
          .post(
        config.stkPushUri(),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': normalized,
          'amount': amount,
          'plan': plan,
        }),
      )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode != 200) {
        yield PaymentStatus(
          state: PaymentState.failed,
          message: 'M-Pesa request failed (${res.statusCode}). ${res.body}',
        );
        return;
      }

      push = StkPushResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    } catch (e) {
      yield PaymentStatus(
        state: PaymentState.failed,
        message: 'Could not reach M-Pesa server: $e',
      );
      return;
    }

    yield PaymentStatus(
      state: PaymentState.awaitingPin,
      checkoutRequestId: push.checkoutRequestId,
      message: push.customerMessage.isNotEmpty
          ? push.customerMessage
          : 'Enter your M-Pesa PIN on your phone.',
    );

    final deadline = DateTime.now().add(const Duration(seconds: 90));
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 3));
      if (!connectivity.isOnline) {
        yield PaymentStatus(
          state: PaymentState.timeout,
          checkoutRequestId: push.checkoutRequestId,
          message: 'Lost connection while checking payment.',
        );
        return;
      }

      try {
        final res = await _http
            .get(config.statusUri(push.checkoutRequestId))
            .timeout(const Duration(seconds: 15));

        if (res.statusCode == 404) continue;
        if (res.statusCode != 200) continue;

        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final current = PaymentStatus.fromJson(
          json,
          checkoutRequestId: push.checkoutRequestId,
        );

        if (current.state == PaymentState.awaitingPin) continue;

        yield current;
        return;
      } catch (_) {
        continue;
      }
    }

    yield PaymentStatus(
      state: PaymentState.timeout,
      checkoutRequestId: push.checkoutRequestId,
      message: 'Still waiting on M-Pesa. If you got an SMS confirmation, it succeeded.',
    );
  }

  void dispose() => _http.close();
}