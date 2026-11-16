import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:craft_pos/app.dart';
import 'package:craft_pos/core/database/app_database.dart';
import 'package:craft_pos/core/providers/database_provider.dart';

void main() {
  testWidgets('App builds', (tester) async {
    final db = AppDatabase();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const App(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  });
}