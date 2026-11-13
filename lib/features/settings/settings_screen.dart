import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _sectionHeader('FINANCE'),
          _settingsTile(
            context,
            icon: Icons.receipt_long,
            title: 'Expenses',
            subtitle: 'One-off and recurring expenses',
            onTap: () => context.push('/settings/expenses'),
          ),
          _settingsTile(
            context,
            icon: Icons.subscriptions,
            title: 'Subscription',
            subtitle: 'Plan, billing and renewal',
            onTap: () => context.push('/settings/subscription'),
          ),

          const Divider(height: 24),
          _sectionHeader('BUSINESS'),

          _settingsTile(
            context,
            icon: Icons.person_outline,
            title: 'About Business (AOB)',
            subtitle: 'Company profile, tax and legal info',
            onTap: () => context.push('/settings/aob'),
          ),

          const Divider(height: 24),
          _sectionHeader('DATA & PRIVACY'),

          _settingsTile(
            context,
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Alerts, stock warnings and summaries',
            onTap: () => context.push('/settings/notifications'),
          ),
          _settingsTile(
            context,
            icon: Icons.backup_outlined,
            title: 'Backup & Sync',
            subtitle: 'Encrypted backups and cloud recovery',
            onTap: () => context.push('/settings/backup'),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.textLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _settingsTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textLight),
      onTap: onTap,
    );
  }
}