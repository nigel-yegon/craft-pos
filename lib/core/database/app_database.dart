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
    HeldOrders,
    Expenses,
    RecurringExpenses,
    Subscriptions,
    PaymentAttempts,
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
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async => await m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createTable(stockMovements);
      if (from < 3) await m.addColumn(businesses, businesses.imagePath);
      if (from < 4) await m.createTable(heldOrders);
      if (from < 5) await m.addColumn(products, products.imagePath);
      if (from < 6) {
        await m.createTable(expenses);
        await m.createTable(recurringExpenses);
      }
      if (from < 7) {
        await m.addColumn(expenses, expenses.paidAmountMinor);
        await m.addColumn(recurringExpenses, recurringExpenses.nextDueDate);
      }
      if (from < 8) {
        await m.createTable(subscriptions);
        await m.createTable(paymentAttempts);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  // ═══ Dashboard Metrics ═══

  Future<int> getBusinessCount() async =>
      (await select(businesses).get()).length;

  Future<int> getProductCount(String businessId) async {
    final query = select(products)
      ..where((p) => p.businessId.equals(businessId) & p.isActive.equals(true));
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
    return results.fold<int>(0, (total, sale) => total + sale.totalAmountMinor);
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

  // ═══ Stock Ledger ═══

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

  // ═══ Stock Valuation (ledger-based) ═══

  /// Total value of all stock on hand, using the cost recorded on each movement.
  Future<int> getTotalStockValueFromLedger(String businessId) async {
    final query = customSelect(
      '''
      SELECT SUM(quantity_milli * COALESCE(unit_cost_minor, 0)) / 1000 AS total_value
      FROM stock_movements
      WHERE business_id = ?
      ''',
      variables: [Variable.withString(businessId)],
      readsFrom: {stockMovements},
    );
    final result = await query.getSingleOrNull();
    return result?.read<int?>('total_value') ?? 0;
  }

  /// Value of stock on hand for one product, using the cost on each movement.
  Future<int> getProductStockValueFromLedger(String productId) async {
    final query = customSelect(
      '''
      SELECT SUM(quantity_milli * COALESCE(unit_cost_minor, 0)) / 1000 AS total_value
      FROM stock_movements
      WHERE product_id = ?
      ''',
      variables: [Variable.withString(productId)],
      readsFrom: {stockMovements},
    );
    final result = await query.getSingleOrNull();
    return result?.read<int?>('total_value') ?? 0;
  }

  /// Convenience helper used by the Stock Report.
  Future<String?> getProductName(String productId) async {
    final row = await (select(products)
      ..where((p) => p.id.equals(productId)))
        .getSingleOrNull();
    return row?.name;
  }
}