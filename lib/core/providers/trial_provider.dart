// lib/core/providers/trial_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'business_provider.dart';
import 'subscription_provider.dart';

const kTrialDuration = Duration(days: 7);

enum TrialStatus { active, expired, subscribed, unknown }

class TrialState {
  final TrialStatus status;
  final int daysRemaining;
  final DateTime? trialEndsAt;

  const TrialState({
    required this.status,
    this.daysRemaining = 0,
    this.trialEndsAt,
  });

  bool get isLocked => status == TrialStatus.expired;
  bool get showTrialBanner =>
      status == TrialStatus.active && daysRemaining <= 3;
}

/// Computes trial state from business + subscription.
/// Sync provider — reads the latest value from both async upstreams.
final trialStatusProvider = Provider<TrialState>((ref) {
  final businessAsync = ref.watch(currentBusinessProvider);
  final isTrialAsync = ref.watch(isTrialProvider);

  final business = businessAsync.value;
  if (business == null) {
    return const TrialState(status: TrialStatus.unknown);
  }

  final hasSubscription = isTrialAsync.value == false;
  if (hasSubscription) {
    return const TrialState(status: TrialStatus.subscribed);
  }

  // ⭐ Prefer trialStartedAt (new column) over createdAt (fallback)
  final trialStart = business.trialStartedAt;
  final trialEnds = trialStart.add(kTrialDuration);
  final now = DateTime.now();

  if (now.isAfter(trialEnds)) {
    return TrialState(
      status: TrialStatus.expired,
      trialEndsAt: trialEnds,
    );
  }

  final remaining = trialEnds.difference(now).inDays + 1;
  return TrialState(
    status: TrialStatus.active,
    daysRemaining: remaining < 0 ? 0 : remaining,
    trialEndsAt: trialEnds,
  );
});