import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class CategoryProvider extends ChangeNotifier {
  final AppDatabase db;
  final String businessId;
  final _uuid = const Uuid();

  CategoryProvider(this.db, this.businessId);

  Stream<List<Category>> get categoriesStream =>
      (db.select(db.categories)..where((c) => c.businessId.equals(businessId))).watch();

  Future<bool> addCategory(String name, {String? description}) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return false;

    try {
      final existing = await (db.select(db.categories)
        ..where((c) => c.businessId.equals(businessId))
        ..where((c) => c.name.equals(trimmedName)))
          .get();

      if (existing.isNotEmpty) return false;

      await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: _uuid.v4(),
          businessId: businessId,
          name: trimmedName,
          description: drift.Value(description?.trim()),
        ),
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving category: $e');
      return false;
    }
  }

  Future<void> deleteCategory(String id) async {
    await (db.delete(db.categories)..where((c) => c.id.equals(id))).go();
    notifyListeners();
  }
}