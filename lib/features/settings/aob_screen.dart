import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class AobScreen extends StatelessWidget {
  const AobScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Business'),
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
              Icon(Icons.person_outline, size: 64, color: AppTheme.primaryGreen),
              SizedBox(height: 16),
              Text('Business profile details are coming soon.',
                  textAlign: TextAlign.center),
              SizedBox(height: 8),
              Text('Tax ID, legal registration and contact information will be stored here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
            ],
          ),
        ),
      ),
    );
  }
}