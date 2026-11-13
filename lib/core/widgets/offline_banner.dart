import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/mpesa_provider.dart';
import '../../../core/theme/app_theme.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityServiceProvider).isOnline;
    if (online) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.burntOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off,
              size: 18, color: AppTheme.burntOrange),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'You are offline. App works normally — M-Pesa payments need internet.',
              style: TextStyle(fontSize: 12, color: AppTheme.inkBlack),
            ),
          ),
        ],
      ),
    );
  }
}