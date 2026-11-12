import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

/// Exposes the single AppDatabase instance across the app.
/// Must be overridden in main.dart with the actual seeded instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'databaseProvider must be overridden in ProviderScope with the AppDatabase '
        'instance created in main(). This ensures a single shared connection.',
  );
});