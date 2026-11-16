// lib/main.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/providers/database_provider.dart';
import 'core/services/business_registration_service.dart';
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

/// Registers every business in the local DB with the server so the
/// admin panel can send notifications to it. Idempotent — safe to
/// call on every launch.
Future<void> _ensureBusinessRegistered(AppDatabase db) async {
  try {
    final businesses = await db.select(db.businesses).get();
    debugPrint('📡 [register] checking ${businesses.length} business(es)');
    for (final b in businesses) {
      final ok = await BusinessRegistrationService.register(
        id: b.id,
        name: b.name,
        phone: b.phone,
        email: b.email,
      );
      if (ok) {
        debugPrint('📡 [register] ${b.id} confirmed on server');
      } else {
        debugPrint('📡 [register] ${b.id} pending — will retry next launch');
      }
    }
  } catch (e) {
    debugPrint('📡 [register] startup check failed: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Restore a staged backup (if any) BEFORE opening the DB.
  await _handlePendingRestore();

  // 2. Open the DB (runs migrations).
  final database = AppDatabase();

  // Debug: confirm what's in the businesses table
  final businesses = await database.select(database.businesses).get();
  debugPrint('🔍 Businesses in DB:');
  for (final b in businesses) {
    debugPrint(
        '   - ${b.id} | ${b.name} | createdAt: ${b.createdAt} | trialStartedAt: ${b.trialStartedAt}');
  }

  // 3. NO SEEDING — fresh DB routes through setup.

  // 4. Connectivity — required by M-Pesa / subscription flows.
  await ConnectivityService.instance.init();

  // 5. ⭐ Retry server registration for any business not yet registered.
  //    Fire-and-forget — never blocks app startup.
  unawaited(_ensureBusinessRegistered(database));

  // 6. Build the app. Router + trial logic all live in providers now.
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: const App(),
    ),
  );
}