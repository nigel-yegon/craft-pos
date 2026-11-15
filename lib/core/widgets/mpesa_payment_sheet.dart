// lib/core/widgets/mpesa_payment_sheet.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:craft_pos/core/models/subscription_plan.dart';
import 'package:craft_pos/core/providers/database_provider.dart';
import 'package:craft_pos/core/providers/mpesa_provider.dart';
import 'package:craft_pos/core/providers/subscription_provider.dart';
import 'package:craft_pos/core/services/mpesa/mpesa_models.dart';
import 'package:craft_pos/core/services/subscription_service.dart';
import 'package:craft_pos/core/theme/app_theme.dart';

class MpesaPaymentSheet extends ConsumerStatefulWidget {
  final SubscriptionPlan plan;

  const MpesaPaymentSheet({super.key, required this.plan});

  @override
  ConsumerState<MpesaPaymentSheet> createState() => _MpesaPaymentSheetState();
}

class _MpesaPaymentSheetState extends ConsumerState<MpesaPaymentSheet> {
  final _phoneController = TextEditingController();
  PaymentStatus _status = PaymentStatus.idle;
  bool _busy = false;

  // Visual countdown during PIN entry.
  Timer? _uiTimer;
  int _secondsRemaining = 90;

  @override
  void dispose() {
    _uiTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startPayment() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _status = PaymentStatus.idle;
      _secondsRemaining = 120; // match STK expiry (90–120s)
    });

    final mpesa = ref.read(mpesaServiceProvider);
    final db = ref.read(databaseProvider);
    final subs = SubscriptionService(db);

    StreamSubscription<PaymentStatus>? sub;
    Timer? hardTimeout;
    bool popped = false;

    void popOnce(bool? result) {
      if (popped || !mounted) return;
      popped = true;
      Navigator.pop(context, result);
    }

    // Fires when the stream goes silent. Treated like a timeout: persist
    // and hand off to the reconciler.
    Future<void> onHardTimeout() async {
      if (popped) return;
      try {
        await subs
            .recordAttempt(
          checkoutRequestId: _status.checkoutRequestId ?? '',
          amount: widget.plan.amountKes,
          plan: widget.plan.id,
          phone: _phoneController.text.trim(),
          state: 'timeout',
          message: 'Client-side timeout — awaiting reconciliation',
        )
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('recordAttempt(hardTimeout) failed: $e');
      }
      popOnce(null);
    }

    try {
      final attempt = await subs.startAttempt(
        amount: widget.plan.amountKes,
        plan: widget.plan.id,
        phone: _phoneController.text.trim(),
      );

      if (attempt == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A payment is already in progress. Please wait.'),
              backgroundColor: AppTheme.burntOrange,
            ),
          );
        }
        popOnce(false);
        return;
      }

      // ⭐ Hard deadline: 120s wall-clock, independent of the stream.
      hardTimeout = Timer(const Duration(seconds: 120), () {
        onHardTimeout();
      });

      final completer = Completer<void>();

      sub = mpesa
          .pay(
        phone: _phoneController.text.trim(),
        amount: widget.plan.amountKes,
        plan: widget.plan.id,
        accountRef: 'SUB-${widget.plan.id.toUpperCase()}',
        description: widget.plan.title,
      )
          .listen(
            (s) async {
          if (!mounted) return;

          setState(() {
            _status = s;
            if (s.state == PaymentState.awaitingPin && _uiTimer == null) {
              _startPollingCountdown();
            }
          });

          if (s.state == PaymentState.awaitingPin &&
              s.checkoutRequestId != null) {
            try {
              await subs.recordAttempt(
                checkoutRequestId: s.checkoutRequestId!,
                amount: widget.plan.amountKes,
                plan: widget.plan.id,
                phone: _phoneController.text.trim(),
                state: 'pending',
              );
            } catch (e) {
              debugPrint('recordAttempt(pending) failed: $e');
            }
          }

          if (s.state == PaymentState.success) {
            hardTimeout?.cancel();
            try {
              await subs
                  .recordAttempt(
                checkoutRequestId: s.checkoutRequestId ?? '',
                amount: widget.plan.amountKes,
                plan: widget.plan.id,
                phone: _phoneController.text.trim(),
                state: 'success',
                receipt: s.receipt,
                message: s.message,
              )
                  .timeout(const Duration(seconds: 5));
            } catch (e) {
              debugPrint('recordAttempt(success) failed: $e');
            }
            try {
              invalidateSubscription(ref);
            } catch (e) {
              debugPrint('invalidateSubscription failed: $e');
            }
            popOnce(true);
            if (!completer.isCompleted) completer.complete();
            return;
          }

          if (s.state == PaymentState.failed) {
            hardTimeout?.cancel();
            try {
              await subs
                  .recordAttempt(
                checkoutRequestId: s.checkoutRequestId ?? '',
                amount: widget.plan.amountKes,
                plan: widget.plan.id,
                phone: _phoneController.text.trim(),
                state: 'failed',
                message: s.message,
              )
                  .timeout(const Duration(seconds: 5));
            } catch (e) {
              debugPrint('recordAttempt(failed) failed: $e');
            }
            popOnce(false);
            if (!completer.isCompleted) completer.complete();
            return;
          }

          if (s.state == PaymentState.timeout) {
            hardTimeout?.cancel();
            try {
              await subs
                  .recordAttempt(
                checkoutRequestId: s.checkoutRequestId ?? '',
                amount: widget.plan.amountKes,
                plan: widget.plan.id,
                phone: _phoneController.text.trim(),
                state: 'timeout',
                message: s.message,
              )
                  .timeout(const Duration(seconds: 5));
            } catch (e) {
              debugPrint('recordAttempt(timeout) failed: $e');
            }
            popOnce(null);
            if (!completer.isCompleted) completer.complete();
            return;
          }
        },
        onError: (e) async {
          debugPrint('payment stream error: $e');
          hardTimeout?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payment failed: $e'),
                backgroundColor: AppTheme.burntOrange,
              ),
            );
          }
          popOnce(false);
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          // Stream ended without a terminal state → treat as timeout.
          if (!completer.isCompleted) {
            if (!popped) onHardTimeout();
            completer.complete();
          }
        },
        cancelOnError: false,
      );

      await completer.future;
    } catch (e) {
      debugPrint('_startPayment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment failed: $e'),
            backgroundColor: AppTheme.burntOrange,
          ),
        );
        popOnce(false);
      }
    } finally {
      // ⭐ Guaranteed cleanup regardless of which path resolved.
      hardTimeout?.cancel();
      await sub?.cancel();
      _uiTimer?.cancel();
      _uiTimer = null;
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _startPollingCountdown() {
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityServiceProvider).isOnline;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        // ⭐ AppTheme.navClearance keeps the sheet's content above the
        //    floating nav pill even in edge cases where the modal-hide-nav
        //    mechanism hasn't kicked in yet.
        bottom: 24 +
            MediaQuery.of(context).viewInsets.bottom +
            AppTheme.navClearance,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone_android, color: AppTheme.heroGreen),
              const SizedBox(width: 8),
              const Text(
                'Pay via M-Pesa',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!online)
            _offlineCard()
          else ...[
            Text(
              '${widget.plan.title} • KSh ${widget.plan.amountKes}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'M-Pesa phone number',
                hintText: '07XX XXX XXX',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 24),

            // ── Status UI ──
            if (_status.state == PaymentState.initiating)
              _statusRow(
                Icons.hourglass_top,
                AppTheme.heroGreen,
                'Sending request to M-Pesa...',
              ),

            if (_status.state == PaymentState.awaitingPin)
              _pinPromptCard(),

            if (_status.state == PaymentState.failed)
              _statusRow(
                Icons.error_outline,
                AppTheme.burntOrange,
                _status.message ?? 'Payment failed.',
              ),

            if (_status.state == PaymentState.timeout)
              _statusRow(
                Icons.info_outline,
                AppTheme.burntOrange,
                _status.message ??
                    'Payment status unknown. Check your SMS.',
              ),

            if (_status.state == PaymentState.success)
              _statusRow(
                Icons.check_circle,
                AppTheme.heroGreen,
                'Payment successful! Activating subscription...',
              ),

            const SizedBox(height: 16),

            // ── Action Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_busy &&
                    _status.state != PaymentState.timeout &&
                    _status.state != PaymentState.failed)
                    ? null
                    : _startPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  _status.state == PaymentState.timeout ||
                      _status.state == PaymentState.failed
                      ? AppTheme.inkBlack
                      : AppTheme.brightGreen,
                  foregroundColor:
                  _status.state == PaymentState.timeout ||
                      _status.state == PaymentState.failed
                      ? Colors.white
                      : AppTheme.inkBlack,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _busy &&
                    _status.state != PaymentState.timeout &&
                    _status.state != PaymentState.failed
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child:
                  CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text(
                  _status.state == PaymentState.timeout ||
                      _status.state == PaymentState.failed
                      ? 'Try Again'
                      : 'Send STK Push',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pinPromptCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.brightGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppTheme.brightGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.sms, color: AppTheme.heroGreen),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _status.message ??
                      'Check your phone and enter your M-Pesa PIN.',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.heroGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _secondsRemaining / 90,
              backgroundColor:
              AppTheme.brightGreen.withValues(alpha: 0.2),
              color: AppTheme.heroGreen,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Waiting for PIN... ${_secondsRemaining}s',
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.onLightMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _offlineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.softMint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You are offline',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          SizedBox(height: 6),
          Text(
            'M-Pesa payments require an internet connection. Your data is safe — reconnect when you have a signal.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}