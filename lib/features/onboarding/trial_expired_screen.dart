// lib/features/onboarding/trial_expired_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class TrialExpiredScreen extends ConsumerWidget {
  const TrialExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.forestDeep,
              AppTheme.heroGreen,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Lock icon in a premium ring
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 40),

                  const Text(
                    'Your trial has ended',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'To keep using Craft Business, activate a subscription. '
                        'Your data is safe — everything stays exactly where you left it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Benefits list
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 0.5,
                      ),
                    ),
                    child: const Column(
                      children: [
                        _BenefitRow(
                          icon: Icons.all_inclusive,
                          text: 'Unlimited products & sales',
                        ),
                        SizedBox(height: 12),
                        _BenefitRow(
                          icon: Icons.bar_chart_rounded,
                          text: 'Advanced reports & insights',
                        ),
                        SizedBox(height: 12),
                        _BenefitRow(
                          icon: Icons.cloud_outlined,
                          text: 'Cloud backups & sync',
                        ),
                        SizedBox(height: 12),
                        _BenefitRow(
                          icon: Icons.support_agent,
                          text: 'Priority support',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Primary CTA
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => context.push('/settings/subscription'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brightGreen,
                        foregroundColor: AppTheme.inkBlack,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.workspace_premium, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Choose a plan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Already subscribed? Tap below to restore access.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppTheme.brightGreen.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: AppTheme.brightGreen),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}