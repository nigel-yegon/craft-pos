import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/providers/database_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/backup_helper.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isProcessing = false;
  DateTime? _lastBackupDate;

  Future<void> _handleDbExport() async {
    setState(() => _isProcessing = true);
    try {
      await BackupHelper.exportDatabase('craft_pos.sqlite');
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _lastBackupDate = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database backup ready!'),
          backgroundColor: AppTheme.heroGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export: $e'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
    }
  }

  Future<void> _handleCsvExport() async {
    setState(() => _isProcessing = true);
    try {
      final db = ref.read(databaseProvider);
      final businesses = await db.select(db.businesses).get();
      if (businesses.isEmpty) return;

      await BackupHelper.exportCsv(db, businesses.first.id);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV report generated successfully!'),
          backgroundColor: AppTheme.heroGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export CSV: $e'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Restore Database?',
          style: TextStyle(
              fontWeight: FontWeight.w700, color: AppTheme.inkBlack),
        ),
        content: const Text(
          'This will completely overwrite your current data with the uploaded file. '
              'The app will close to apply the changes. Are you sure?',
          style: TextStyle(color: AppTheme.onLightSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.burntOrange),
            child: const Text('Restore Now',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);

    final success = await BackupHelper.stageDatabaseRestore();

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Restore Staged',
              style: TextStyle(color: AppTheme.inkBlack)),
          content: const Text(
            'Your backup has been staged. Please completely close and restart the app to apply the restored data.',
            style: TextStyle(color: AppTheme.onLightSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore cancelled or the selected file was invalid.'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
    }
  }

  void _handleCloudBackup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cloud sync will be available in a future update.'),
        backgroundColor: AppTheme.midnightViolet,
      ),
    );
  }

  /// Verifies the entered PIN against the users table.
  /// ⚠️ The salt must match `AuthProvider._hashPin`.
  Future<bool> _verifyShopPin(String pin) async {
    try {
      final db = ref.read(databaseProvider);
      final users = await db.select(db.users).get();
      if (users.isEmpty) return false;
      final salt = 'craft_pos_salt_$pin';
      final hash = sha256.convert(utf8.encode(salt)).toString();
      return users.any((u) => u.pinHash == hash);
    } catch (e) {
      debugPrint('verifyShopPin failed: $e');
      return false;
    }
  }

  // ⭐ PIN-verified reset flow — uses _ResetPinDialog to own the controller.
  Future<void> _handleResetShop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResetPinDialog(
        onVerify: (pin) => _verifyShopPin(pin),
      ),
    );

    if (confirmed != true || !mounted) return;

    // Blocking spinner while the wipe runs.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.burntOrange),
      ),
    );

    try {
      final db = ref.read(databaseProvider);
      await db.wipeAllData();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (!mounted) return;
      context.go('/setup');
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reset shop: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Backup & Sync'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.inkBlack),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Protect your data',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.inkBlack,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your data is stored locally on this device. Export a backup regularly to prevent data loss if your phone is lost or stolen.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.onLightMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // ═══ LOCAL EXPORTS ═══
            _buildSectionCard(
              title: 'Export Data',
              icon: Icons.download_outlined,
              iconColor: AppTheme.heroGreen,
              children: [
                if (_lastBackupDate != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Last local backup: ${DateFormat('dd MMM, HH:mm').format(_lastBackupDate!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.heroGreen,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _handleDbExport,
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text('DB File'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.heroGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _handleCsvExport,
                        icon: const Icon(Icons.table_chart, size: 18),
                        label: const Text('CSV Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.midGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ═══ RESTORE ═══
            _buildSectionCard(
              title: 'Restore Data',
              icon: Icons.upload_file_outlined,
              iconColor: AppTheme.burntOrange,
              children: [
                const Text(
                  'Upload a previously saved .db or .sqlite backup file to restore your shop data.',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.onLightSecondary),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _handleRestore,
                    icon: const Icon(Icons.upload,
                        size: 18, color: AppTheme.burntOrange),
                    label: const Text('Upload Backup File'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.burntOrange,
                      side:
                      const BorderSide(color: AppTheme.burntOrange),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ═══ CLOUD BACKUP ═══
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.inkBlack.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.midnightViolet
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cloud_outlined,
                                color: AppTheme.midnightViolet, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Cloud Backup',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.inkBlack,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.midnightViolet,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'COMING SOON',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Automatically sync your data to the cloud for real-time protection and easy migration to new devices.',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.onLightSecondary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _handleCloudBackup,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.midnightViolet,
                        side: const BorderSide(
                            color: AppTheme.midnightViolet),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Notify Me'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ═══ INFO ═══
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.burntOrange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.burntOrange.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      color: AppTheme.burntOrange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Warning: Restoring a database will completely overwrite your current shop data, products, and sales.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.inkBlack.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ═══ RESET SHOP (danger zone) ═══
            const SizedBox(height: 32),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'RESET & CLEANUP',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppTheme.burntOrange,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.burntOrange.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.burntOrange.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.burntOrange
                              .withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_forever_outlined,
                            color: AppTheme.burntOrange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Reset Shop',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.burntOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Permanently delete all products, sales, transactions, expenses, and shop settings. '
                        'You will be taken back to setup to start fresh.',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.onLightSecondary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isProcessing ? null : _handleResetShop,
                      icon: const Icon(Icons.restart_alt,
                          size: 18, color: AppTheme.burntOrange),
                      label: const Text('Delete all data & start over'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.burntOrange,
                        side:
                        const BorderSide(color: AppTheme.burntOrange),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.inkBlack.withValues(alpha: 0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// RESET PIN DIALOG (owns its TextEditingController)
// ═══════════════════════════════════════════════════════════════════

class _ResetPinDialog extends StatefulWidget {
  final Future<bool> Function(String pin) onVerify;

  const _ResetPinDialog({required this.onVerify});

  @override
  State<_ResetPinDialog> createState() => _ResetPinDialogState();
}

class _ResetPinDialogState extends State<_ResetPinDialog> {
  final _pinController = TextEditingController();
  String? _errorText;
  bool _isVerifying = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      setState(() => _errorText = 'Enter a 4-digit PIN');
      return;
    }
    setState(() {
      _isVerifying = true;
      _errorText = null;
    });
    final ok = await widget.onVerify(pin);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _isVerifying = false;
        _errorText = 'Incorrect PIN';
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.burntOrange),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reset shop?',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppTheme.inkBlack),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This will permanently delete:',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppTheme.inkBlack),
          ),
          const SizedBox(height: 8),
          const Text(
            '• Products and categories\n'
                '• Sales and transactions\n'
                '• Stock movements\n'
                '• Held orders\n'
                '• Expenses and recurring expenses\n'
                '• Users and shop settings\n'
                '• Subscription and notifications',
            style: TextStyle(color: AppTheme.onLightSecondary),
          ),
          const SizedBox(height: 16),
          const Text(
            'This cannot be undone. Enter your shop PIN to confirm.',
            style: TextStyle(fontSize: 12, color: AppTheme.onLightMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pinController,
            autofocus: true,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            textAlign: TextAlign.center,
            enabled: !_isVerifying,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 12,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              counterText: '',
              errorText: _errorText,
              hintText: '••••',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isVerifying ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.burntOrange,
            foregroundColor: Colors.white,
          ),
          child: _isVerifying
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Text('Delete everything'),
        ),
      ],
    );
  }
}