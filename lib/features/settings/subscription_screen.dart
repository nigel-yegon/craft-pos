import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:craft_pos/core/models/subscription_plan.dart';
import 'package:craft_pos/core/providers/mpesa_provider.dart';
import 'package:craft_pos/core/theme/app_theme.dart';
import 'package:craft_pos/core/widgets/activation_code_section.dart';
import 'package:craft_pos/core/widgets/current_plan_card.dart';
import 'package:craft_pos/core/widgets/mpesa_payment_sheet.dart';
import 'package:craft_pos/core/widgets/offline_banner.dart';
import 'package:craft_pos/core/widgets/plan_card.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() =>
      _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  int _selectedPlanIndex = 1;

  SubscriptionPlan get _selectedPlan =>
      SubscriptionPlan.all[_selectedPlanIndex];

  void _scrollToPlans() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Select a plan below to continue.'),
        backgroundColor: AppTheme.heroGreen,
      ),
    );
  }

  Future<void> _startSubscribe() async {
    final online = ref.read(connectivityServiceProvider).isOnline;
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'You are offline. Reconnect to pay via M-Pesa, or use an activation code below.',
          ),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
      return;
    }

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MpesaPaymentSheet(plan: _selectedPlan),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription activated!'),
          backgroundColor: AppTheme.heroGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Subscription'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.inkBlack),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OfflineBanner(),
            CurrentPlanCard(onUpgradeTap: _scrollToPlans),
            const SizedBox(height: 32),
            const Text(
              'Choose your plan',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.inkBlack,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upgrade to unlock unlimited stock management, advanced reports, and cloud backups.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.onLightMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ...SubscriptionPlan.all.asMap().entries.map((entry) {
              final index = entry.key;
              final plan = entry.value;
              return PlanCard(
                plan: plan,
                isSelected: _selectedPlanIndex == index,
                onTap: () => setState(() => _selectedPlanIndex = index),
              );
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startSubscribe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brightGreen,
                  foregroundColor: AppTheme.inkBlack,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  'Subscribe to ${_selectedPlan.title}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 40),
            const ActivationCodeSection(),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'Safe and secure payment via M-Pesa',
                style: TextStyle(fontSize: 12, color: AppTheme.onLightMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}