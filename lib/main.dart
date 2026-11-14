import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:drift/drift.dart' as drift;

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/seed_data.dart';
import 'core/providers/database_provider.dart';
import 'core/providers/notifications_provider.dart';
import 'core/services/connectivity_service.dart';

/// Restores a staged backup (if any) BEFORE the DB is opened.
Future<void> _handlePendingRestore() async {
  try {
    final dbFolder = await getApplicationDocumentsDirectory();
    final mainDb = File(p.join(dbFolder.path, 'craft_pos.sqlite'));
    final stagedFile =
    File(p.join(dbFolder.path, 'craft_pos_restore_pending.sqlite'));

    if (await stagedFile.exists()) {
      if (await mainDb.exists()) {
        await mainDb.delete();
      }
      await stagedFile.rename(mainDb.path);
      debugPrint('✅ Database restored successfully from backup.');
    }
  } catch (e) {
    debugPrint('❌ Error applying database restore: $e');
  }
}

/// Resolves the active business ID after seeding / restoring.
///
/// Prefers the first business in the DB (the seed creates exactly one:
/// `demo-business-id`). Only falls back to a literal when the DB is
/// genuinely empty — which shouldn't happen after seed/restore, so log
/// loudly if we hit it.
Future<String> _resolveBusinessId(AppDatabase db) async {
  final businesses = await db.select(db.businesses).get();

  if (businesses.isNotEmpty) {
    return businesses.first.id;
  }

  // No business in the DB — this only happens if the seed was skipped
  // (restore that wiped everything, or a fresh DB where seedIfEmpty
  // returned early for some reason). Create one so FK-based tables work.

  await db.into(db.businesses).insert(
    BusinessesCompanion.insert(
      id: 'demo-business-id',
      name: 'My Shop',
      phone: drift.Value('0700000000'),
    ),
  );
  return 'demo-business-id';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Restore a staged backup (if any) BEFORE opening the DB.
  await _handlePendingRestore();

  // 2. Open the DB (runs migrations).
  final database = AppDatabase();

  // 3. Seed demo data on a fresh install — does nothing if already seeded.
  await SeedData.seedIfEmpty(database);

  // 4. Resolve the active business ID (used by notifications, M-Pesa, etc.).
  final businessId = await _resolveBusinessId(database);

  // 5. Connectivity — required by M-Pesa / subscription flows.
  await ConnectivityService.instance.init();

  // 6. Build the app, overriding providers with runtime values.
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        currentBusinessIdProvider.overrideWithValue(businessId),
      ],
      child: App(database: database, initialRoute: '/dashboard'),
    ),
  );
}