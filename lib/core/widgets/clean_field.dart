import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CleanField extends StatelessWidget {
  final String label;
  final Widget child;    // usually a TextField or DropdownButtonFormField
  final String? error;
  final String? helper;

  const CleanField({
    super.key,
    required this.label,
    required this.child,
    this.error,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Uppercase micro-label with wide tracking
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w500,
              color: AppTheme.wheat.withValues(alpha: 0.55),
            ),
          ),
        ),
        child,
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 4),
            child: Text(
              helper!,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.wheat.withValues(alpha: 0.35),
              ),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 4),
            child: Text(
              error!,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.warning,
              ),
            ),
          ),
      ],
    );
  }
}