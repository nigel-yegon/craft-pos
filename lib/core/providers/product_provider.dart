import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

class ProductProvider extends ChangeNotifier {
  final AppDatabase db;
  final String businessId;
  ProductProvider(this.db, this.businessId);

  Stream<List<Product>> get productsStream => (db.select(db.products)
    ..where((p) => p.businessId.equals(businessId) & (p.isActive.equals(true))))
      .watch();
  /// Adjust stock for a product by creating a new ledger entry.
  /// [deltaMilli] is positive to add stock, negative to remove.
  /// Returns the new movement id.
  Future<String> adjustStock({
    required String productId,
    required int deltaMilli,
    required String reason, // 'purchase', 'adjustment', 'damage', 'return', etc.
    String? note,
    int? unitCostMinor,
  }) async {
    final movementId = const Uuid().v4();

    await db.into(db.stockMovements).insert(
      StockMovementsCompanion.insert(
        id: movementId,
        businessId: businessId,
        productId: productId,
        type: reason,
        quantityMilli: deltaMilli,
        unitCostMinor: drift.Value(unitCostMinor),
        note: drift.Value(note?.trim().isEmpty == true ? null : note?.trim()),
      ),
    );

    notifyListeners();
    return movementId;
  }
  /// Reactive stream of all stock movements for this business, newest first.
  Stream<List<StockMovement>> get stockLedgerStream =>
      (db.select(db.stockMovements)
        ..where((m) => m.businessId.equals(businessId))
        ..orderBy([(m) => drift.OrderingTerm.desc(m.createdAt)]))
          .watch();

  /// Total stock (in milli-units) for a single product.
  Future<int> getProductStockMilli(String productId) async {
    final query = db.selectOnly(db.stockMovements)
      ..addColumns([db.stockMovements.quantityMilli.sum()])
      ..where(db.stockMovements.productId.equals(productId));
    final result = await query.getSingle();
    return result.read(db.stockMovements.quantityMilli.sum()) ?? 0;
  }

  /// Aggregate movements per product for a summary table.
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

      result.add({
        'product': p,
        'totalIn': totalIn,
        'totalOut': totalOut,
        'balance': balance,
        'isLow': balance <= p.reorderLevelMilli,
      });
    }
    return result;
  }
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
}