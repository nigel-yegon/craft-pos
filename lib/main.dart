import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import 'app.dart';
import 'core/database/app_database.dart';
import 'core/database/seed_data.dart';
import 'core/providers/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final hasSeenSplash = prefs.getBool('hasSeenSplash') ?? false;
  final initialRoute = hasSeenSplash ? '/dashboard' : '/splash';

  final database = AppDatabase();

  // ⭐ Seed demo data if the database is empty.
  //    If a real business already exists, this does nothing.
  await SeedData.seedIfEmpty(database);

  // Fallback: if seed somehow skipped (e.g., real business exists but no
  // default row with 'default-business-id'), ensure a row exists.
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

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: App(database: database, initialRoute: initialRoute),
    ),
  );
}