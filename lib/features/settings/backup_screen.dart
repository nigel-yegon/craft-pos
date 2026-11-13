import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Sync'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.backup_outlined, size: 64, color: AppTheme.primaryGreen),
              SizedBox(height: 16),
              Text('Encrypted backup and restore is coming soon.',
                  textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text('Cloud backup, device migration and manual encrypted exports will be managed here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
            ],
          ),
        ),
      ),
    );
  }
}