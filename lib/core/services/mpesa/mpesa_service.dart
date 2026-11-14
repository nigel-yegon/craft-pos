// lib/core/services/mpesa/mpesa_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  // ═══════════════════════════════════════════════════════════════
  // PHONE NORMALIZATION
  // ═══════════════════════════════════════════════════════════════

  /// Normalizes a Kenyan phone number to `2547XXXXXXXX` / `2541XXXXXXXX`.
  /// Returns the input unchanged if it doesn't match a known pattern.
  static String normalizePhone(String input) {
    var p = input.replaceAll(RegExp(r'\s+'), '');
    if (p.startsWith('+')) p = p.substring(1);
    if (p.startsWith('0')) return '254${p.substring(1)}';
    if (p.startsWith('254')) return p;
    if (p.startsWith('7') && p.length == 9) return '254$p';
    if (p.startsWith('1') && p.length == 9) return '254$p';
    return p;
  }

  // ═══════════════════════════════════════════════════════════════
  // PAY — streaming STK push + poll loop
  // ═══════════════════════════════════════════════════════════════

  /// Initiates an STK push, then polls the backend until a terminal state
  /// or the 90-second deadline is reached.
  ///
  /// Emits (in order, typically):
  ///   1. `initiating`
  ///   2. `awaitingPin` (after the backend accepts the push)
  ///   3. one of `success` / `failed` / `timeout` (terminal)
  ///
  /// Every emitted `PaymentStatus` carries the `checkoutRequestId` once the
  /// push is accepted, so callers can persist it against an attempt.
  Stream<PaymentStatus> pay({
    required String phone,
    required int amount,
    required String accountRef,
    required String description,
    required String plan,
  }) async* {
    // ── Pre-flight checks ─────────────────────────────────────────
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

    // ── STK push initiation ───────────────────────────────────────
    StkPushResponse push;
    try {
      final res = await _http
          .post(
        config.stkPushUri(),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
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
          message: _extractErrorMessage(res),
        );
        return;
      }

      push = StkPushResponse.fromJson(
        jsonDecode(res.body) as Map<String, dynamic>,
      );

      if (push.checkoutRequestId.isEmpty) {
        yield const PaymentStatus(
          state: PaymentState.failed,
          message: 'Backend did not return a checkout request id.',
        );
        return;
      }
    } catch (e) {
      debugPrint('STK PUSH EXCEPTION: $e');
      yield PaymentStatus(
        state: PaymentState.failed,
        message: _formatTransportError(e),
      );
      return;
    }

    // ── Awaiting PIN ──────────────────────────────────────────────
    yield PaymentStatus(
      state: PaymentState.awaitingPin,
      checkoutRequestId: push.checkoutRequestId,
      message: push.customerMessage.isNotEmpty
          ? push.customerMessage
          : 'Enter your M-Pesa PIN on your phone.',
    );

    // ── Poll loop ─────────────────────────────────────────────────
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

        // Backend hasn't seen the id yet — keep polling.
        if (res.statusCode == 404) continue;

        // Transient backend error — keep polling, don't fail the flow.
        if (res.statusCode != 200) continue;

        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final current = PaymentStatus.fromJson(
          json,
          checkoutRequestId: push.checkoutRequestId,
        );

        // Still awaiting PIN — keep polling.
        if (current.isPending) continue;

        // Terminal state — emit and stop.
        yield current;
        return;
      } catch (e) {
        // Network blip — retry next tick.
        debugPrint('Status poll error: $e');
        continue;
      }
    }

    // ── Deadline reached without a terminal state ─────────────────
    yield PaymentStatus(
      state: PaymentState.timeout,
      checkoutRequestId: push.checkoutRequestId,
      message:
      'Still waiting on M-Pesa. If you got an SMS confirmation, it succeeded.',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // QUERY — used by SubscriptionReconcileService
  // ═══════════════════════════════════════════════════════════════

  /// Queries the current state of an existing STK push.
  ///
  /// Called by `SubscriptionReconcileService` when a pending payment attempt
  /// has gone stale (i.e. older than `staleThreshold` but younger than
  /// `abandonThreshold`).
  ///
  /// Returns a [MpesaStkQueryResult] mapping:
  ///   • `PaymentState.success`     → `MpesaStkQueryState.success`
  ///   • `PaymentState.failed`      → `MpesaStkQueryState.failed`
  ///   • `PaymentState.timeout`     → `MpesaStkQueryState.failed`
  ///   • anything else (idle / initiating / awaitingPin)
  ///                                 → `MpesaStkQueryState.pending`
  ///
  /// **Never throws** — transport errors are mapped to `pending` so the
  /// reconciler just retries on the next tick.
  Future<MpesaStkQueryResult> queryStkStatus({
    required String checkoutRequestId,
  }) async {
    if (!connectivity.isOnline) {
      return const MpesaStkQueryResult(
        state: MpesaStkQueryState.pending,
        message: 'Offline — will retry when connection returns',
      );
    }

    try {
      final res = await _http
          .get(config.statusUri(checkoutRequestId))
          .timeout(const Duration(seconds: 15));

      // 404 = backend doesn't know the id yet → still pending.
      if (res.statusCode == 404) {
        return const MpesaStkQueryResult(
          state: MpesaStkQueryState.pending,
          message: 'Not yet known to backend',
        );
      }

      // 5xx = transient backend problem → leave alone and retry.
      if (res.statusCode >= 500) {
        return MpesaStkQueryResult(
          state: MpesaStkQueryState.pending,
          message: 'Backend error ${res.statusCode}',
        );
      }

      // Any other non-200 — also treat as pending to avoid premature failure.
      if (res.statusCode != 200) {
        return MpesaStkQueryResult(
          state: MpesaStkQueryState.pending,
          message: 'Unexpected backend status ${res.statusCode}',
        );
      }

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final current = PaymentStatus.fromJson(
        json,
        checkoutRequestId: checkoutRequestId,
      );

      // Exhaustive over PaymentState — no default so a future enum
      // addition produces a compile error instead of silently
      // bucketing into 'pending'.
      switch (current.state) {
        case PaymentState.success:
          return MpesaStkQueryResult(
            state: MpesaStkQueryState.success,
            receipt: current.receipt,
            message: current.message,
          );

        case PaymentState.failed:
        case PaymentState.timeout:
          return MpesaStkQueryResult(
            state: MpesaStkQueryState.failed,
            receipt: current.receipt,
            message: current.message,
          );

        case PaymentState.idle:
        case PaymentState.initiating:
        case PaymentState.awaitingPin:
          return MpesaStkQueryResult(
            state: MpesaStkQueryState.pending,
            receipt: current.receipt,
            message: current.message,
          );
      }
    } catch (e) {
      debugPrint('STK QUERY EXCEPTION: $e');
      return MpesaStkQueryResult(
        state: MpesaStkQueryState.pending,
        message: 'Query error: $e',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  /// Extracts the most useful error message from a non-200 backend response.
  String _extractErrorMessage(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        final error = body['error']?.toString() ??
            body['message']?.toString() ??
            'Server returned ${res.statusCode}';
        final detail = body['detail']?.toString();
        return detail == null ? error : '$error: $detail';
      }
    } catch (_) {
      // Body wasn't JSON — fall through to raw.
    }
    return '${res.statusCode}: ${res.body}';
  }

  /// Turns a transport exception into a user-readable message.
  String _formatTransportError(Object e) {
    final raw = e.toString();
    if (raw.contains('Failed host lookup')) {
      return 'Cannot resolve server address. Check your internet connection.';
    }
    if (raw.contains('Failed to fetch')) {
      return 'Network error (CORS). The browser blocked the request.';
    }
    if (raw.contains('TimeoutException')) {
      return 'Server took too long to respond. Please try again.';
    }
    return 'Connection failed: $raw';
  }

  // ═══════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════

  void dispose() => _http.close();
}