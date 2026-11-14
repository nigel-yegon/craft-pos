import 'package:craft_pos/core/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:craft_pos/core/models/subscription_model.dart';
import 'package:craft_pos/core/models/subscription_plan.dart';
import 'package:craft_pos/core/providers/mpesa_provider.dart';
import 'package:craft_pos/core/services/subscription_service.dart';
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

  // ⭐ Lazily built service. If you already have a provider for it
  //    (e.g. `subscriptionServiceProvider`), swap this for `ref.read(...)`.
  SubscriptionService get _subs =>
      SubscriptionService(ref.read(databaseProvider));

  void _scrollToPlans() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Select a plan below to continue.'),
        backgroundColor: AppTheme.heroGreen,
      ),
    );
  }

  Future<void> _startSubscribe(PaymentAttempt? pending) async {
    // ⭐ Guard 1: refuse if anything is pending.
    if (pending != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A payment is already in progress. Please wait.'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
      return;
    }

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

    // The sheet handles startAttempt() + recordAttempt() internally.
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MpesaPaymentSheet(plan: _selectedPlan),
    );

    if (!mounted) return;

    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription activated!'),
          backgroundColor: AppTheme.heroGreen,
        ),
      );
    }
    // If result == null, the payment is still pending — the StreamBuilder
    // below will show the pending banner automatically.
  }

  // ⭐ Called from the pending banner's Cancel button. Marks the attempt
  //    as timeout. If M-Pesa already charged, the reconciler will flip it
  //    to success on the next pass — nothing is lost.
  Future<void> _cancelPending(PaymentAttempt pending) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text(
          'We will stop waiting for M-Pesa. If the payment already went through, '
              'your subscription will still be activated automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep waiting'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel payment'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _subs.resolveAttempt(
      attemptId: pending.id,
      state: PaymentAttemptState.timeout,
      message: 'Cancelled by user',
    );
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
      body: StreamBuilder<SubscriptionState>(
        stream: _subs.watchFullState(),
        builder: (context, snapshot) {
          // Fallback to empty state while the first snapshot arrives —
          // the screen stays interactive (plans still tappable) but the
          // button is disabled until we know if there's a pending attempt.
          final state = snapshot.data ?? SubscriptionState.empty;
          final pending = state.pendingAttempt;
          final isLocked = pending != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OfflineBanner(),

                // ⭐ Pending payment banner.
                if (pending != null) ...[
                  _PendingPaymentBanner(
                    attempt: pending,
                    onCancel: () => _cancelPending(pending),
                  ),
                  const SizedBox(height: 16),
                ],

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

                // ⭐ Plan tiles: disabled while pending.
                ...SubscriptionPlan.all.asMap().entries.map((entry) {
                  final index = entry.key;
                  final plan = entry.value;
                  return Opacity(
                    opacity: isLocked ? 0.5 : 1.0,
                    child: IgnorePointer(
                      ignoring: isLocked,
                      child: PlanCard(
                        plan: plan,
                        isSelected: _selectedPlanIndex == index,
                        onTap: () =>
                            setState(() => _selectedPlanIndex = index),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    // ⭐ Disabled while pending.
                    onPressed:
                    isLocked ? null : () => _startSubscribe(pending),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLocked
                          ? AppTheme.surfaceMuted
                          : AppTheme.brightGreen,
                      foregroundColor: isLocked
                          ? AppTheme.onLightMuted
                          : AppTheme.inkBlack,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(
                      isLocked
                          ? 'Payment in progress…'
                          : 'Subscribe to ${_selectedPlan.title}',
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
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.onLightMuted),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PENDING PAYMENT BANNER
// ═══════════════════════════════════════════════════════════════════

class _PendingPaymentBanner extends StatelessWidget {
  final PaymentAttempt attempt;
  final VoidCallback onCancel;

  const _PendingPaymentBanner({
    required this.attempt,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.burntOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.burntOrange.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.burntOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment in progress',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.inkBlack,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Waiting for M-Pesa confirmation for KSh ${attempt.amount}…',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.inkBlack.withValues(alpha: 0.6),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.burntOrange),
            ),
          ),
        ],
      ),
    );
  }
}