// lib/core/providers/notifications_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../services/notifications_service.dart';
import 'database_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// CONFIGURATION (override at startup if you have a real source)
// ═══════════════════════════════════════════════════════════════════

/// Active business for this session. Override at ProviderScope startup
/// with `currentBusinessIdProvider.overrideWithValue(myBusinessId)`.
final currentBusinessIdProvider = Provider<String>((ref) {
  return 'default-business-id';   // used until overridden at startup
});

/// Base URL for the Craft POS VPS — same host as M-Pesa.
final apiBaseUrlProvider = Provider<String>((ref) {
  return 'https://craft.co.ke/api';
});
// ═══════════════════════════════════════════════════════════════════
// SERVICE (singleton per business)
// ═══════════════════════════════════════════════════════════════════

final notificationsServiceProvider = Provider<NotificationsService>((ref) {
  final db = ref.watch(databaseProvider);
  return NotificationsService(
    db: db,
    businessId: ref.watch(currentBusinessIdProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  );
});

// ═══════════════════════════════════════════════════════════════════
// STREAMS
// ═══════════════════════════════════════════════════════════════════

/// Full list, newest first. Powers the notifications screen.
final notificationsStreamProvider =
StreamProvider.autoDispose<List<Notification>>((ref) {
  return ref.watch(notificationsServiceProvider).watch();
});

/// Unread badge count. Powers the dashboard bell.
final unreadNotificationsCountProvider =
StreamProvider.autoDispose<int>((ref) {
  return ref.watch(notificationsServiceProvider).watchUnreadCount();
});

// ═══════════════════════════════════════════════════════════════════
// ACTIONS (UI calls these instead of the service)
// ═══════════════════════════════════════════════════════════════════

final notificationsSyncProvider = Provider<Future<void> Function()>((ref) {
  final svc = ref.watch(notificationsServiceProvider);
  return () => svc.sync();
});

final markNotificationReadProvider =
Provider<Future<void> Function(String id)>((ref) {
  final svc = ref.watch(notificationsServiceProvider);
  return (id) => svc.markAsRead(id);
});

final markAllNotificationsReadProvider =
Provider<Future<void> Function()>((ref) {
  final svc = ref.watch(notificationsServiceProvider);
  return () => svc.markAllAsRead();
});