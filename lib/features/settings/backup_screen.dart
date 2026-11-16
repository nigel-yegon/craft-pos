// lib/features/settings/backup_screen.dart

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/business_provider.dart';
import '../../core/providers/cloud_backup_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/trial_provider.dart';
import '../../core/services/cloud_backup_service.dart';
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

  // Cloud backup state
  bool _cloudUploading = false;
  bool _cloudLoading = false;
  List<CloudBackup> _cloudBackups = [];

  @override
  void initState() {
    super.initState();
    // Load cloud backups on first open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCloudBackups();
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // LOCAL EXPORTS
  // ═══════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════
  // LOCAL RESTORE
  // ═══════════════════════════════════════════════════════════════════

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
      _showRestoreStagedDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restore cancelled or the selected file was invalid.'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
    }
  }

  void _showRestoreStagedDialog() {
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
  }

  // ═══════════════════════════════════════════════════════════════════
  // CLOUD BACKUP
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _refreshCloudBackups() async {
    final business = ref.read(currentBusinessProvider).value;
    if (business == null) {
      debugPrint('☁️ [cloud] no business yet, skipping refresh');
      return;
    }

    setState(() => _cloudLoading = true);
    try {
      final backups = await ref.read(cloudBackupServiceProvider).list();
      if (!mounted) return;
      setState(() {
        _cloudBackups = backups;
        _cloudLoading = false;
      });
      debugPrint('☁️ [cloud] loaded ${backups.length} backups');
    } catch (e) {
      debugPrint('☁️ [cloud] refresh failed: $e');
      if (!mounted) return;
      setState(() => _cloudLoading = false);
    }
  }

  Future<void> _uploadToCloud() async {
    final business = ref.read(currentBusinessProvider).value;
    if (business == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete shop setup first'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
      return;
    }

    setState(() => _cloudUploading = true);
    try {
      final id = await ref
          .read(cloudBackupServiceProvider)
          .upload(databaseName: 'craft_pos.sqlite');
      if (!mounted) return;
      setState(() => _cloudUploading = false);

      if (id != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup uploaded to cloud'),
            backgroundColor: AppTheme.heroGreen,
          ),
        );
        await _refreshCloudBackups();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed — check your connection'),
            backgroundColor: AppTheme.burntOrange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _cloudUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
    }
  }

  Future<void> _restoreFromCloud(CloudBackup backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Restore from cloud?',
          style: TextStyle(
              fontWeight: FontWeight.w700, color: AppTheme.inkBlack),
        ),
        content: Text(
          'This will download the backup from '
              '${DateFormat('dd MMM yyyy, HH:mm').format(backup.createdAt)} '
              '(${backup.displaySize}) and stage it for restore. '
              'You will need to restart the app for changes to apply.',
          style: const TextStyle(color: AppTheme.onLightSecondary),
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
            child: const Text('Restore',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    final ok = await ref
        .read(cloudBackupServiceProvider)
        .downloadAndStage(backup.id);

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (ok) {
      _showRestoreStagedDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download failed — check your connection'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // RESET
  // ═══════════════════════════════════════════════════════════════════

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

  Future<void> _handleResetShop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResetPinDialog(
        onVerify: (pin) => _verifyShopPin(pin),
      ),
    );

    if (confirmed != true || !mounted) return;

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

  // ═══════════════════════════════════════════════════════════════════
  // DEBUG — trial backdate helper
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _backdateTrial({required int days}) async {
    try {
      final db = ref.read(databaseProvider);
      final business = ref.read(currentBusinessProvider).value;
      if (business == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No business — complete setup first')),
        );
        return;
      }

      final targetDate = days == 0
          ? DateTime.now()
          : DateTime.now().subtract(Duration(days: days));

      await (db.update(db.businesses)
        ..where((b) => b.id.equals(business.id)))
          .write(
        BusinessesCompanion(trialStartedAt: Value(targetDate)),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            days == 0
                ? 'Trial reset — starts now'
                : 'Trial backdated $days days — expiring now',
          ),
          backgroundColor: AppTheme.heroGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update trial: $e'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

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
              'Your data is stored locally on this device. Export a backup regularly or use Cloud Backup to protect against phone loss.',
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

            // ═══ CLOUD BACKUP ═══
            _buildCloudSection(),

            const SizedBox(height: 24),

            // ═══ RESTORE FROM FILE ═══
            _buildSectionCard(
              title: 'Restore from File',
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

            // ═══ TRIAL STATUS (debug only) ═══
            if (kDebugMode) ...[
              const SizedBox(height: 32),
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'TRIAL (DEBUG)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: AppTheme.heroGreen,
                  ),
                ),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final trial = ref.watch(trialStatusProvider);
                  final business = ref.watch(currentBusinessProvider).value;
                  final trialStart = business?.trialStartedAt;

                  final statusLabel = switch (trial.status) {
                    TrialStatus.active => 'Active',
                    TrialStatus.expired => 'Expired',
                    TrialStatus.subscribed => 'Subscribed',
                    TrialStatus.unknown => 'Unknown',
                  };

                  final statusColor = switch (trial.status) {
                    TrialStatus.active => AppTheme.heroGreen,
                    TrialStatus.expired => AppTheme.burntOrange,
                    TrialStatus.subscribed => AppTheme.midGreen,
                    TrialStatus.unknown => AppTheme.onLightMuted,
                  };

                  return _buildSectionCard(
                    title: 'Trial Status',
                    icon: Icons.timer_outlined,
                    iconColor: AppTheme.heroGreen,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (trial.status == TrialStatus.active)
                            Text(
                              '${trial.daysRemaining} day(s) remaining',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkBlack,
                              ),
                            ),
                          if (trial.status == TrialStatus.subscribed)
                            const Text(
                              'Full access',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkBlack,
                              ),
                            ),
                          if (trial.status == TrialStatus.expired)
                            const Text(
                              'Trial has ended',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.inkBlack,
                              ),
                            ),
                        ],
                      ),
                      if (trialStart != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Started: ${DateFormat('dd MMM yyyy, HH:mm').format(trialStart)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.onLightMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Debug tools — expire the trial to test the lock screen.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.onLightMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _backdateTrial(days: 8),
                              icon: const Icon(Icons.lock_clock, size: 16),
                              label: const Text('Expire Trial'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.burntOrange,
                                side: const BorderSide(
                                    color: AppTheme.burntOrange),
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _backdateTrial(days: 0),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Reset Trial'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.heroGreen,
                                side: const BorderSide(
                                    color: AppTheme.heroGreen),
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
            ],

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

  // ═══════════════════════════════════════════════════════════════════
  // CLOUD BACKUP SECTION
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCloudSection() {
    return _buildSectionCard(
      title: 'Cloud Backup',
      icon: Icons.cloud_outlined,
      iconColor: AppTheme.midnightViolet,
      children: [
        const Text(
          'Save a snapshot of your data to the cloud. Restore it anytime from any device.',
          style: TextStyle(fontSize: 13, color: AppTheme.onLightSecondary),
        ),
        const SizedBox(height: 16),

        // Upload button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _cloudUploading ? null : _uploadToCloud,
            icon: _cloudUploading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(_cloudUploading ? 'Uploading…' : 'Backup to cloud'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.midnightViolet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Section header with refresh
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent cloud backups',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.inkBlack,
              ),
            ),
            TextButton.icon(
              onPressed: _cloudLoading ? null : _refreshCloudBackups,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text(
                'Refresh',
                style: TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.midnightViolet,
              ),
            ),
          ],
        ),

        // Backup list
        if (_cloudLoading)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.midnightViolet,
                ),
              ),
            ),
          )
        else if (_cloudBackups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No cloud backups yet. Tap "Backup to cloud" to create one.',
              style: TextStyle(fontSize: 12, color: AppTheme.onLightMuted),
            ),
          )
        else
          ..._cloudBackups.map(
                (b) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.midnightViolet.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.midnightViolet.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cloud_done_outlined,
                    color: AppTheme.midnightViolet,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy, HH:mm')
                              .format(b.createdAt),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.inkBlack,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b.displaySize,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.onLightMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () => _restoreFromCloud(b),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.burntOrange,
                    ),
                    child: const Text(
                      'Restore',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════

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
// RESET PIN DIALOG
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