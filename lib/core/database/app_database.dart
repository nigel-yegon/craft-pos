import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Businesses,
    Categories,
    Products,
    Sales,
    SaleItems,
    StockMovements,
    Users,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      : super(
    driftDatabase(
      name: 'craft_pos',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.dart.js'),
      ),
    ),
  );

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => await m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(stockMovements);
      }
      if (from < 3) {
        await m.addColumn(businesses, businesses.imagePath);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ─── Dashboard Metrics ────────────────────────────────────────────

  Future<int> getBusinessCount() async =>
      (await select(businesses).get()).length;

  Future<int> getProductCount(String businessId) async {
    final query = select(products)
      ..where((p) =>
      p.businessId.equals(businessId) & p.isActive.equals(true));
    return (await query.get()).length;
  }

  Future<int> getTodaySales(String businessId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final query = select(sales)
      ..where((s) =>
      s.businessId.equals(businessId) &
      s.status.equals('completed') &
      s.createdAt.isBiggerOrEqualValue(start) &
      s.createdAt.isSmallerThanValue(end));

    final results = await query.get();
    return results.fold<int>(0, (total, s) => total + s.totalAmountMinor);
  }

  Future<int> getTodayTransactionCount(String businessId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final query = select(sales)
      ..where((s) =>
      s.businessId.equals(businessId) &
      s.status.equals('completed') &
      s.createdAt.isBiggerOrEqualValue(start) &
      s.createdAt.isSmallerThanValue(end));

    return (await query.get()).length;
  }

  // ─── Stock Ledger ─────────────────────────────────────────────────

  Future<int> getProductStock(String productId) async {
    final query = selectOnly(stockMovements)
      ..addColumns([stockMovements.quantityMilli.sum()])
      ..where(stockMovements.productId.equals(productId));
    final result = await query.getSingle();
    return result.read(stockMovements.quantityMilli.sum()) ?? 0;
  }

  Future<int> getLowStockCount(String businessId) async {
    final query = customSelect(
      '''
      SELECT COUNT(*) AS low_stock_count
      FROM (
        SELECT p.id, p.reorder_level_milli,
               COALESCE(SUM(sm.quantity_milli), 0) AS current_stock
        FROM products p
        LEFT JOIN stock_movements sm ON p.id = sm.product_id
        WHERE p.business_id = ? AND p.is_active = 1
        GROUP BY p.id
      ) AS stock_calc
      WHERE current_stock <= reorder_level_milli
      ''',
      variables: [Variable.withString(businessId)],
      readsFrom: {products, stockMovements},
    );
    final result = await query.getSingleOrNull();
    return result?.read<int?>('low_stock_count') ?? 0;
  }
}