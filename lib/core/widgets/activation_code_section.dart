import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:craft_pos/core/providers/database_provider.dart';
import 'package:craft_pos/core/theme/app_theme.dart';
import 'package:craft_pos/core/services/subscription_service.dart';

/// Lets the user redeem an activation code instead of paying via M-Pesa.
class ActivationCodeSection extends ConsumerStatefulWidget {
  const ActivationCodeSection({super.key});

  @override
  ConsumerState<ActivationCodeSection> createState() =>
      _ActivationCodeSectionState();
}

class _ActivationCodeSectionState
    extends ConsumerState<ActivationCodeSection> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static final _codePattern =
      RegExp(r'^[A-Z0-9]{3,8}(-[A-Z0-9]{3,8}){0,2}$');

  Future<void> _redeem() async {
    final raw = _controller.text.trim().toUpperCase();
    if (!_codePattern.hasMatch(raw)) {
      setState(() => _error = 'Invalid code format.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final match = _lookupCode(raw);
      if (match == null) {
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _error = 'That code is not valid or has already been used.';
        });
        return;
      }

      final service = SubscriptionService(ref.read(databaseProvider));
      await service.activateExternal(plan: match.plan, source: 'code');

      if (!mounted) return;
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Activation code redeemed. Enjoy your plan!'),
          backgroundColor: AppTheme.heroGreen,
        ),
      );
      setState(() => _submitting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Could not redeem code: $e';
      });
    }
  }

  // ⚠️ Placeholder — replace with a DB/API lookup before shipping.
  ({String plan})? _lookupCode(String code) {
    const codes = <String, String>{
      'FREE-WEEK-2025': 'weekly',
      'WELCOME-MONTH': 'monthly',
      'YEAR-FREE-PROMO': 'yearly',
    };
    final plan = codes[code];
    return plan == null ? null : (plan: plan);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.inkBlack.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppTheme.softMint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.confirmation_number_outlined,
                  size: 18,
                  color: AppTheme.heroGreen,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Have an activation code?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkBlack,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enter your code below to activate your plan without paying '
            'via M-Pesa.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.inkBlack.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_submitting,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
                  ],
                  decoration: InputDecoration(
                    hintText: 'XXXX-XXXX',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                    errorText: _error,
                  ),
                  onSubmitted: (_) => _redeem(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _redeem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.heroGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Redeem',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
