// lib/features/settings/notifications_screen.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' hide Notification;

import '../../core/database/app_database.dart';
import '../../core/providers/notifications_provider.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsStreamProvider);
    final sync = ref.read(notificationsSyncProvider);
    final markAll = ref.read(markAllNotificationsReadProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.inkBlack),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => markAll(),
            child: const Text(
              'Mark all read',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.heroGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: sync,
        color: AppTheme.heroGreen,
        child: async.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.heroGreen),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load notifications: $e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.onLightMuted),
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) return _buildEmptyState(context);
            // ...
            return ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildCard(context, ref, items[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, Notification n) {
    final markOne = ref.read(markNotificationReadProvider);
    final (IconData icon, Color iconColor, Color bgColor) = switch (n.type) {
      'subscription' => (
      Icons.card_membership,
      AppTheme.midnightViolet,
      AppTheme.midnightViolet.withValues(alpha: 0.08),
      ),
      'code' => (
      Icons.vpn_key,
      AppTheme.brightGreen,
      AppTheme.softMint,
      ),
      'alert' => (
      Icons.warning_amber_rounded,
      AppTheme.burntOrange,
      AppTheme.burntOrange.withValues(alpha: 0.08),
      ),
      'backup' => (
      Icons.backup_outlined,
      AppTheme.heroGreen,
      AppTheme.softMint,
      ),
      _ => (
      Icons.info_outline,
      AppTheme.heroGreen,
      AppTheme.softMint,
      ),
    };

    return GestureDetector(
      onTap: () async {
        await markOne(n.id);
        if (n.actionRoute != null && context.mounted) {
          context.push(n.actionRoute!);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: n.isRead ? Colors.white : bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: n.isRead
                ? AppTheme.inkBlack.withValues(alpha: 0.06)
                : iconColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: n.isRead ? AppTheme.softMint : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: n.isRead
                                ? FontWeight.w600
                                : FontWeight.w700,
                            color: AppTheme.inkBlack,
                          ),
                        ),
                      ),
                      if (!n.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.brightGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.onLightSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(n.publishedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.onLightMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children:  [
        SizedBox(height: MediaQuery.of(context).padding.top + 120),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppTheme.softMint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_off_outlined,
                  size: 48,
                  color: AppTheme.heroGreen,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No notifications yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkBlack,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We will notify you about subscriptions,\nalerts, and updates here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.onLightMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat('dd MMM').format(date);
  }
}