import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:craft_pos/core/providers/database_provider.dart';
import 'package:craft_pos/core/providers/mpesa_provider.dart';
import 'package:craft_pos/core/providers/subscription_provider.dart';
import 'package:craft_pos/core/services/mpesa/mpesa_models.dart';
import 'package:craft_pos/core/services/subscription_service.dart';
import 'package:craft_pos/core/theme/app_theme.dart';
import 'package:craft_pos/core/models/subscription_plan.dart';

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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _startPayment() async {
    setState(() => _busy = true);

    final mpesa = ref.read(mpesaServiceProvider);
    final db = ref.read(databaseProvider);
    final subService = SubscriptionService(db);

    final stream = mpesa.pay(
      phone: _phoneController.text.trim(),
      amount: widget.plan.amountKes,
      accountRef: 'SUB-${widget.plan.id.toUpperCase()}',
      description: widget.plan.title,
    );

    await for (final s in stream) {
      if (!mounted) return;
      setState(() => _status = s);

      if (s.state == PaymentState.success) {
        await subService.activate(plan: widget.plan.id, source: 'mpesa');
        await subService.recordAttempt(
          checkoutRequestId: s.checkoutRequestId ?? '',
          amount: widget.plan.amountKes,
          plan: widget.plan.id,
          phone: _phoneController.text,
          state: 'success',
          receipt: s.receipt,
          message: s.message,
        );
        if (mounted) {
          invalidateSubscription(ref);
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.pop(context, true);
        }
        return;
      }

      if (s.state == PaymentState.failed) {
        await subService.recordAttempt(
          checkoutRequestId: s.checkoutRequestId ?? '',
          amount: widget.plan.amountKes,
          plan: widget.plan.id,
          phone: _phoneController.text,
          state: 'failed',
          message: s.message,
        );
        break;
      }

      if (s.state == PaymentState.timeout) {
        await subService.recordAttempt(
          checkoutRequestId: s.checkoutRequestId ?? '',
          amount: widget.plan.amountKes,
          plan: widget.plan.id,
          phone: _phoneController.text,
          state: 'pending',
          message: s.message,
        );
        break;
      }
    }

    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(connectivityServiceProvider).isOnline;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
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
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
            const SizedBox(height: 20),
            if (_status.state == PaymentState.initiating)
              _statusRow(Icons.hourglass_top, AppTheme.heroGreen,
                  'Sending request to M-Pesa…'),
            if (_status.state == PaymentState.awaitingPin)
              _statusRow(Icons.sms_outlined, AppTheme.heroGreen,
                  'Check your phone and enter your M-Pesa PIN.'),
            if (_status.state == PaymentState.failed)
              _statusRow(Icons.error_outline, AppTheme.burntOrange,
                  _status.message ?? 'Payment failed.'),
            if (_status.state == PaymentState.timeout)
              _statusRow(Icons.info_outline, AppTheme.burntOrange,
                  _status.message ?? 'Payment status unknown.'),
            if (_status.state == PaymentState.success)
              _statusRow(Icons.check_circle, AppTheme.heroGreen,
                  'Payment successful!'),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : _startPayment,
                child: _busy
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text('Send STK Push'),
              ),
            ),
          ],
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
            'M-Pesa payments require an internet connection. Your data is safe — reconnect when you have a signal, or use an activation code instead.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }
}