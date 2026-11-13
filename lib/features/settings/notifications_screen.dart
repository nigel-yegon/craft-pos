import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Dummy data for the MVP.
  // In production, this would be a Stream from a Notifications table in SQLite.
  final List<Map<String, dynamic>> _notifications = [
    {
      'type': 'subscription',
      'title': 'Subscription Expiring Soon',
      'body': 'Your Monthly plan will expire in 3 days. Renew now to avoid interruptions.',
      'time': DateTime.now().subtract(const Duration(hours: 2)),
      'isRead': false,
    },
    {
      'type': 'code',
      'title': 'Activation Code',
      'body': 'Thank you for your payment! Your activation code is: CRFT-X7Y2-9B1P',
      'time': DateTime.now().subtract(const Duration(days: 1)),
      'isRead': false,
    },
    {
      'type': 'alert',
      'title': 'Low Stock Alert',
      'body': 'Coca-Cola 500ml and 2 other items are running low on stock.',
      'time': DateTime.now().subtract(const Duration(days: 2)),
      'isRead': true,
    },
    {
      'type': 'system',
      'title': 'Backup Successful',
      'body': 'Your local database backup was generated successfully.',
      'time': DateTime.now().subtract(const Duration(days: 3)),
      'isRead': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
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
          // Mark all as read button
          TextButton(
            onPressed: () {
              setState(() {
                for (var n in _notifications) {
                  n['isRead'] = true;
                }
              });
            },
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
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final type = notification['type'] as String;
    final isRead = notification['isRead'] as bool;

    // Determine icon and color based on type
    IconData icon;
    Color iconColor;
    Color bgColor;

    switch (type) {
      case 'subscription':
        icon = Icons.card_membership;
        iconColor = AppTheme.midnightViolet;
        bgColor = AppTheme.midnightViolet.withValues(alpha: 0.08);
        break;
      case 'code':
        icon = Icons.vpn_key;
        iconColor = AppTheme.brightGreen;
        bgColor = AppTheme.softMint;
        break;
      case 'alert':
        icon = Icons.warning_amber_rounded;
        iconColor = AppTheme.burntOrange;
        bgColor = AppTheme.burntOrange.withValues(alpha: 0.08);
        break;
      default: // system
        icon = Icons.info_outline;
        iconColor = AppTheme.heroGreen;
        bgColor = AppTheme.softMint;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          notification['isRead'] = true;
        });
        // Optional: Route to specific screens based on type
        // if (type == 'subscription') context.push('/settings/subscription');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isRead
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
                color: isRead ? AppTheme.softMint : Colors.white,
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
                      Text(
                        notification['title'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                          color: AppTheme.inkBlack,
                        ),
                      ),
                      if (!isRead)
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
                    notification['body'],
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.onLightSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(notification['time']),
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

  Widget _buildEmptyState() {
    return Center(
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
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mins ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('dd MMM').format(date);
    }
  }
}