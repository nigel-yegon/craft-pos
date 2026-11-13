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
import 'core/services/connectivity_service.dart';

Future<void> _handlePendingRestore() async {
  try {
    final dbFolder = await getApplicationDocumentsDirectory();
    final mainDb = File(p.join(dbFolder.path, 'craft_pos.sqlite'));
    final stagedFile =
    File(p.join(dbFolder.path, 'craft_pos_restore_pending.sqlite'));

    if (await stagedFile.exists()) {
      // 1. Delete the old database
      if (await mainDb.exists()) {
        await mainDb.delete();
      }
      // 2. Move the staged file to become the new active database
      await stagedFile.rename(mainDb.path);

      debugPrint('✅ Database restored successfully from backup.');
    }
  } catch (e) {
    debugPrint('❌ Error applying database restore: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Check for and apply any staged restores BEFORE opening the DB
  await _handlePendingRestore();

  // 2. Initialize DB (runs migrations — creates subscriptions/payment_attempts
  //    on upgrade if you bumped schemaVersion in app_database.dart)
  final database = AppDatabase();

  // 3. Seed if empty (only if it's a fresh install, won't override a restore)
  await SeedData.seedIfEmpty(database);

  final businesses = await database.select(database.businesses).get();
  if (businesses.isEmpty) {
    await database.into(database.businesses).insert(
      BusinessesCompanion.insert(
        id: 'default-business-id',
        name: 'My Shop',
        phone: drift.Value('0700000000'),
      ),
    );
  }

  // 4. Init connectivity service — required by M-Pesa / subscription flow.
  //    The app remains fully offline-capable; this only tells payment flows
  //    whether an online attempt is possible.
  await ConnectivityService.instance.init();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: App(database: database, initialRoute: '/dashboard'),
    ),
  );
}