import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:craft_pos/core/models/subscription_plan.dart';
import 'package:craft_pos/core/providers/database_provider.dart';
import 'package:craft_pos/core/providers/subscription_provider.dart';
import 'package:craft_pos/core/services/subscription_service.dart';
import 'package:craft_pos/core/theme/app_theme.dart';

class ActivationCodeSection extends ConsumerStatefulWidget {
  const ActivationCodeSection({super.key});

  @override
  ConsumerState<ActivationCodeSection> createState() =>
      _ActivationCodeSectionState();
}

class _ActivationCodeSectionState
    extends ConsumerState<ActivationCodeSection> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _snack('Please enter an activation code');
      return;
    }

    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    SubscriptionPlan? plan;
    if (code.startsWith('CRFT-YR')) {
      plan = SubscriptionPlan.byId('yearly');
    } else if (code.startsWith('CRFT-MO')) {
      plan = SubscriptionPlan.byId('monthly');
    } else if (code.startsWith('CRFT-WK')) {
      plan = SubscriptionPlan.byId('weekly');
    } else if (code.startsWith('CRFT-')) {
      plan = SubscriptionPlan.byId('monthly');
    }

    if (plan == null) {
      setState(() => _isVerifying = false);
      _snack('Invalid code. Please check and try again.', error: true);
      return;
    }

    final db = ref.read(databaseProvider);
    await SubscriptionService(db).activate(plan: plan.id, source: 'code');
    if (!mounted) return;
    invalidateSubscription(ref);
    _codeController.clear();
    setState(() => _isVerifying = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.heroGreen,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.brightGreen),
            SizedBox(width: 8),
            Text('Activated!', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Your ${plan!.title} subscription is now active.',
          style: const TextStyle(color: AppTheme.onHeroSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done',
                style: TextStyle(color: AppTheme.brightGreen)),
          ),
        ],
      ),
    );
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.burntOrange : AppTheme.heroGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(child: Divider(color: Color(0xFFE8F7EE))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onLightMuted,
                ),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFFE8F7EE))),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Already have a code?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.inkBlack,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'If you paid via M-Pesa or bought an activation card, enter the code below. Works offline.',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.onLightMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'CRFT-XXXX-XXXX',
                  filled: true,
                  fillColor: AppTheme.softMint,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isVerifying ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.inkBlack,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isVerifying
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Text('Verify',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}