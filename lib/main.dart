import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;
import 'app.dart';
import 'core/database/app_database.dart';
import 'core/providers/database_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final hasSeenSplash = prefs.getBool('hasSeenSplash') ?? false;
  final initialRoute = hasSeenSplash ? '/dashboard' : '/splash';

  // 1. Create the single AppDatabase instance
  final database = AppDatabase();

  // 2. Seed a default business if none exists
  final businesses = await database.select(database.businesses).get();
  if (businesses.isEmpty) {
    await database.into(database.businesses).insert(
      BusinessesCompanion.insert(
        id: 'default-business-id',
        name: 'My Shop',
        phone: drift.Value('0700000000'),
      ),
    );
    debugPrint('✅ Seeded default business.');
  }

  runApp(
    ProviderScope(
      // ⭐ Override the provider so all consumers share the seeded DB
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: App(database: database, initialRoute: initialRoute),
    ),
  );
}