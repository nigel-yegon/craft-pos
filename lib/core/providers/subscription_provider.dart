import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:craft_pos/core/models/subscription_model.dart';
import 'package:craft_pos/core/providers/database_provider.dart';
import 'package:craft_pos/core/services/subscription_service.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final db = ref.watch(databaseProvider);
  return SubscriptionService(db);
});

/// Just the active plan (null = free trial).
final activeSubscriptionProvider =
FutureProvider.autoDispose<SubscriptionModel?>((ref) async {
  final svc = ref.watch(subscriptionServiceProvider);
  return svc.getActive();
});

/// Full state — active plan + recent attempts.
final subscriptionStateProvider =
FutureProvider.autoDispose<SubscriptionState>((ref) async {
  final svc = ref.watch(subscriptionServiceProvider);
  return svc.loadFullState();
});

void invalidateSubscription(WidgetRef ref) {
  ref.invalidate(subscriptionStateProvider);
  ref.invalidate(activeSubscriptionProvider);
}