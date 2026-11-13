import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../database/app_database.dart';
import 'package:drift/drift.dart' hide Column;

class BackupHelper {
  // ═══════════════════════════════════════════════════════════════════
  // 1. LOCAL DATABASE EXPORT (.sqlite)
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> exportDatabase(String databaseName) async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, databaseName));

      if (!await dbFile.exists()) throw Exception("Database file not found.");

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupPath = p.join(dbFolder.path, 'craft_pos_backup_$timestamp.db');
      final backupFile = await dbFile.copy(backupPath);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(backupFile.path)],
          text: 'Craft POS Database Backup',
        ),
      );

      await backupFile.delete();
    } catch (e) {
      debugPrint('Backup failed: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. CSV EXPORT
  // ═══════════════════════════════════════════════════════════════════
  static Future<void> exportCsv(AppDatabase db, String businessId) async {
    try {
      final rows = <List<dynamic>>[];

      // ── Sheet 1: Sales ──
      rows.add(['--- SALES REPORT ---']);
      rows.add(['Date', 'Receipt/ID', 'Payment Method', 'Total (KSh)']);

      final sales = await (db.select(db.sales)
        ..where((s) => s.businessId.equals(businessId))
        ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
          .get();

      for (final sale in sales) {
        rows.add([
          sale.createdAt.toIso8601String(),
          sale.id.substring(0, 8),
          sale.paymentMethod ?? 'Cash',
          (sale.totalAmountMinor / 100).toStringAsFixed(2),
        ]);
      }

      rows.add([]); // Empty line

      // ── Sheet 2: Products ──
      rows.add(['--- INVENTORY REPORT ---']);
      rows.add(['Product Name', 'SKU', 'Cost Price (KSh)', 'Selling Price (KSh)']);

      final products = await (db.select(db.products)
        ..where((pr) => pr.businessId.equals(businessId)))
          .get();

      for (final product in products) {
        rows.add([
          product.name,
          product.sku ?? '',
          (product.costPriceMinor / 100).toStringAsFixed(2),
          (product.sellingPriceMinor / 100).toStringAsFixed(2),
        ]);
      }

      rows.add([]); // Empty line

      // ── Sheet 3: Expenses ──
      rows.add(['--- EXPENSES REPORT ---']);
      rows.add(['Expense Name', 'Category', 'Status', 'Amount (KSh)']);

      final expenses = await (db.select(db.expenses)
        ..where((e) => e.businessId.equals(businessId)))
          .get();

      for (final expense in expenses) {
        rows.add([
          expense.name,
          expense.category,
          expense.status,
          (expense.amountMinor / 100).toStringAsFixed(2),
        ]);
      }

      // Convert to CSV String
      String csvData = const ListToCsvConverter().convert(rows);

      // Save & Share
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final path = '${directory.path}/CraftPOS_Report_$timestamp.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Craft POS CSV Export',
        ),
      );
    } catch (e) {
      debugPrint('CSV Export failed: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. DATABASE RESTORE (Staged)
  // ═══════════════════════════════════════════════════════════════════
  /// Picks a .db file and stages it to replace the current DB on next launch.
  static Future<bool> stageDatabaseRestore() async {
    try {
      // ⭐ Fixed: Instantiate FilePicker

      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.isEmpty || result.first.path == null) return false;

      final selectedFile = File(result.first.path!);

      // Basic validation (we expect a SQLite database)
      if (!selectedFile.path.endsWith('.db') && !selectedFile.path.endsWith('.sqlite')) {
        throw Exception("Please select a valid .db or .sqlite backup file.");
      }

      final dbFolder = await getApplicationDocumentsDirectory();
      final stagedFile = File(p.join(dbFolder.path, 'craft_pos_restore_pending.sqlite'));

      // Copy the selected file to a staged location
      await selectedFile.copy(stagedFile.path);

      return true;
    } catch (e) {
      debugPrint('Restore staging failed: $e');
      return false;
    }
  }
}