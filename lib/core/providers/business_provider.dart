import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import 'database_provider.dart';

// ⭐ Global provider — the single source of truth for the active business.
// Returns null if no business exists yet (first-run / post-wipe).
final currentBusinessProvider = StreamProvider<BusinessesData?>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.businesses).watchSingleOrNull();
});

class BusinessProvider extends ChangeNotifier {
  final AppDatabase db;
  final String businessId;
  BusinessProvider(this.db, this.businessId);

  Stream<BusinessesData?> get businessStream =>
      (db.select(db.businesses)..where((b) => b.id.equals(businessId)))
          .watchSingleOrNull();

  Future<void> updateBusiness({
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    await (db.update(db.businesses)..where((b) => b.id.equals(businessId)))
        .write(
      BusinessesCompanion(
        name: drift.Value(name.trim()),
        phone: drift.Value(phone?.trim()),
        email: drift.Value(email?.trim()),
        address: drift.Value(address?.trim()),
      ),
    );
    notifyListeners();
  }

  Future<void> pickAndSaveImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    final docs = await getApplicationDocumentsDirectory();
    final filename =
        'shop_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
    final saved = await File(picked.path).copy(p.join(docs.path, filename));

    await (db.update(db.businesses)..where((b) => b.id.equals(businessId)))
        .write(
      BusinessesCompanion(imagePath: drift.Value(saved.path)),
    );
    notifyListeners();
  }
}