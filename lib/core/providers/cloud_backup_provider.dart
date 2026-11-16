// lib/core/providers/cloud_backup_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cloud_backup_service.dart';
import 'business_provider.dart';
import 'database_provider.dart';

final cloudBackupServiceProvider = Provider<CloudBackupService>((ref) {
  final db = ref.watch(databaseProvider);
  final business = ref.watch(currentBusinessProvider).value;
  return CloudBackupService(
    db: db,
    businessId: business?.id ?? '',
    baseUrl: 'https://craft.co.ke/api',
  );
});