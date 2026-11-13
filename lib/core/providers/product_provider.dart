import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class ProductProvider extends ChangeNotifier {
  final AppDatabase db;
  final String businessId;
  ProductProvider(this.db, this.businessId);

  Stream<List<Product>> get productsStream => (db.select(db.products)
    ..where((p) => p.businessId.equals(businessId))
    ..where((p) => p.isActive.equals(true)))
      .watch();

  Stream<List<StockMovement>> get stockLedgerStream =>
      (db.select(db.stockMovements)
        ..where((m) => m.businessId.equals(businessId))
        ..orderBy([(m) => drift.OrderingTerm.desc(m.createdAt)]))
          .watch();

  // ═══ Save / create product ═══

  Future<void> saveProduct({
    String? id,
    required String name,
    String? sku,
    String? barcode,
    String? categoryId,
    required int costPriceMinor,
    required int sellingPriceMinor,
    required int reorderLevelMilli,
    int? openingStockMilli,
    String? imagePath,
  }) async {
    final productId = id ?? const Uuid().v4();

    await db.transaction(() async {
      await db.into(db.products).insertOnConflictUpdate(
        ProductsCompanion(
          id: drift.Value(productId),
          businessId: drift.Value(businessId),
          categoryId: drift.Value(categoryId),
          name: drift.Value(name),
          sku: drift.Value(sku),
          barcode: drift.Value(barcode),
          costPriceMinor: drift.Value(costPriceMinor),
          sellingPriceMinor: drift.Value(sellingPriceMinor),
          reorderLevelMilli: drift.Value(reorderLevelMilli),
          imagePath: imagePath != null
              ? drift.Value(imagePath)
              : const drift.Value.absent(),
        ),
      );

      if (id == null && openingStockMilli != null && openingStockMilli > 0) {
        await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            id: const Uuid().v4(),
            businessId: businessId,
            productId: productId,
            type: 'opening_stock',
            quantityMilli: openingStockMilli,
            unitCostMinor: drift.Value(costPriceMinor),
          ),
        );
      }
    });
    notifyListeners();
  }

  // ═══ Image ═══

  Future<String?> pickAndSaveProductImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return null;

    final docs = await getApplicationDocumentsDirectory();
    final filename =
        'product_${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
    final saved = await File(picked.path).copy(p.join(docs.path, filename));
    return saved.path;
  }

  // ═══ Stock adjustments ═══

  Future<String> adjustStock({
    required String productId,
    required int deltaMilli,
    required String reason,
    String? note,
    int? unitCostMinor,
  }) async {
    final movementId = const Uuid().v4();

    // For incoming stock, fall back to the product's current cost price
    // when the caller didn't supply a batch-specific cost.
    int? effectiveCost = unitCostMinor;
    if (effectiveCost == null && deltaMilli > 0) {
      final product = await (db.select(db.products)
        ..where((p) => p.id.equals(productId)))
          .getSingleOrNull();
      effectiveCost = product?.costPriceMinor;
    }

    await db.into(db.stockMovements).insert(
      StockMovementsCompanion.insert(
        id: movementId,
        businessId: businessId,
        productId: productId,
        type: reason,
        quantityMilli: deltaMilli,
        unitCostMinor: drift.Value(effectiveCost),
        note: drift.Value(
            note?.trim().isEmpty == true ? null : note?.trim()),
      ),
    );

    notifyListeners();
    return movementId;
  }

  Future<int> getProductStockMilli(String productId) async {
    final query = db.selectOnly(db.stockMovements)
      ..addColumns([db.stockMovements.quantityMilli.sum()])
      ..where(db.stockMovements.productId.equals(productId));
    final result = await query.getSingle();
    return result.read(db.stockMovements.quantityMilli.sum()) ?? 0;
  }

  Future<int> getProductStockValue(String productId) async =>
      db.getProductStockValueFromLedger(productId);

  Future<int> getTotalStockValue() async =>
      db.getTotalStockValueFromLedger(businessId);

  // ═══ Summary for Stock Report ═══

  Future<List<Map<String, dynamic>>> getStockSummary() async {
    final products = await (db.select(db.products)
      ..where((p) => p.businessId.equals(businessId))
      ..where((p) => p.isActive.equals(true)))
        .get();

    final result = <Map<String, dynamic>>[];

    for (final p in products) {
      final inQuery = db.customSelect(
        '''
        SELECT COALESCE(SUM(quantity_milli), 0) as total
        FROM stock_movements
        WHERE product_id = ? AND quantity_milli > 0
        ''',
        variables: [drift.Variable.withString(p.id)],
        readsFrom: {db.stockMovements},
      );
      final inRow = await inQuery.getSingleOrNull();
      final totalIn = inRow?.read<int?>('total') ?? 0;

      final outQuery = db.customSelect(
        '''
        SELECT COALESCE(SUM(quantity_milli), 0) as total
        FROM stock_movements
        WHERE product_id = ? AND quantity_milli < 0
        ''',
        variables: [drift.Variable.withString(p.id)],
        readsFrom: {db.stockMovements},
      );
      final outRow = await outQuery.getSingleOrNull();
      final totalOut = (outRow?.read<int?>('total') ?? 0).abs();

      final balance = totalIn - totalOut;
      final valueMinor = await db.getProductStockValueFromLedger(p.id);
      final avgCostMinor =
      balance > 0 ? (valueMinor * 1000 ~/ balance) : p.costPriceMinor;

      result.add({
        'product': p,
        'totalIn': totalIn,
        'totalOut': totalOut,
        'balance': balance,
        'valueMinor': valueMinor,
        'avgCostMinor': avgCostMinor,
        'isLow': balance <= p.reorderLevelMilli,
      });
    }
    return result;
  }
}