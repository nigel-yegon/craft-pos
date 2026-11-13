import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:craft_pos/core/models/subscription_model.dart';
import 'package:craft_pos/core/providers/subscription_provider.dart';
import 'package:craft_pos/core/theme/app_theme.dart';

class CurrentPlanCard extends ConsumerWidget {
  final VoidCallback onUpgradeTap;

  const CurrentPlanCard({super.key, required this.onUpgradeTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(activeSubscriptionProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.heroGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.heroGreen.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: subAsync.when(
        loading: () => _skeleton(),
        error: (_, __) => _skeleton(),
        data: (SubscriptionModel? sub) {
          final isTrial = sub == null;
          final expires = sub == null
              ? null
              : DateFormat('dd MMM yyyy').format(sub.expiresAt);
          final title = isTrial ? 'Free Trial' : sub.planTitle;
          final description = isTrial
              ? 'You have limited access to core features. Upgrade to unlock unlimited sales, cloud backup, and advanced reporting.'
              : 'Active until $expires. Enjoy full access to all features.';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CURRENT PLAN',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onHeroMuted,
                    ),
                  ),
                  _badge(isTrial ? 'DEMO MODE' : 'ACTIVE'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onHeroSecondary,
                  height: 1.4,
                ),
              ),
              if (sub != null && sub.isExpiringSoon)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Expires in ${sub.daysRemaining} '
                        'day${sub.daysRemaining == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.brightGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onUpgradeTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: Text(
                    isTrial ? 'Upgrade Now' : 'Renew / Change Plan',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _badge(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.brightGreen,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: AppTheme.inkBlack,
        letterSpacing: 0.5,
      ),
    ),
  );

  Widget _skeleton() => const SizedBox(
    height: 160,
    child: Center(
      child: CircularProgressIndicator(color: Colors.white),
    ),
  );
}