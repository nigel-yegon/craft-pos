import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../database/app_database.dart';

class ReportProvider extends ChangeNotifier {
  final AppDatabase db;
  final String businessId;

  ReportProvider(this.db, this.businessId);

  // ═══ Summary methods ═══

  Future<Map<String, int>> getDailySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _getSummary(start, end);
  }

  Future<Map<String, int>> getWeeklySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return _getSummary(start, end);
  }

  Future<Map<String, int>> getMonthlySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 29));
    final end = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    return _getSummary(start, end);
  }

  Future<Map<String, int>> _getSummary(
      DateTime start, DateTime end) async {
    final salesQuery = db.select(db.sales)
      ..where((s) => s.businessId.equals(businessId))
      ..where((s) => s.status.equals('completed'))
      ..where((s) => s.createdAt.isBiggerOrEqualValue(start))
      ..where((s) => s.createdAt.isSmallerThanValue(end));

    final sales = await salesQuery.get();
    final totalSales =
    sales.fold<int>(0, (sum, s) => sum + s.totalAmountMinor);

    final profitQuery = db.customSelect(
      '''
      SELECT SUM((si.unit_price_minor - si.cost_price_minor) * (si.quantity_milli / 1000.0)) as profit
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.business_id = ? AND s.status = 'completed'
      AND s.created_at >= ? AND s.created_at < ?
      ''',
      variables: [
        Variable.withString(businessId),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {db.sales, db.saleItems},
    );
    final profitResult = await profitQuery.getSingleOrNull();
    final totalProfit =
    (profitResult?.read<double?>('profit') ?? 0).round();

    // ⭐ Stock valuation now comes straight from the ledger.
    final totalStockValue =
    await db.getTotalStockValueFromLedger(businessId);

    return {
      'sales': totalSales,
      'profit': totalProfit,
      'stockValue': totalStockValue,
    };
  }

  // ═══ Sales trend ═══

  Future<List<Map<String, dynamic>>> getSalesTrend() async {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];

    for (int i = 6; i >= 0; i--) {
      final day =
      DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayEnd = day.add(const Duration(days: 1));

      final query = db.customSelect(
        '''
        SELECT SUM(total_amount_minor) as total
        FROM sales
        WHERE business_id = ? AND status = 'completed'
        AND created_at >= ? AND created_at < ?
        ''',
        variables: [
          Variable.withString(businessId),
          Variable.withDateTime(day),
          Variable.withDateTime(dayEnd),
        ],
        readsFrom: {db.sales},
      );

      final row = await query.getSingleOrNull();
      final total = row?.read<int?>('total') ?? 0;

      result.add({
        'day': day,
        'label': '${day.day}/${day.month}',
        'total': total,
      });
    }
    return result;
  }

  // ═══ Transactions in range ═══

  Future<List<Sale>> getSalesInRange(DateTime start, DateTime end) async {
    return await (db.select(db.sales)
      ..where((s) => s.businessId.equals(businessId))
      ..where((s) => s.status.equals('completed'))
      ..where((s) => s.createdAt.isBiggerOrEqualValue(start))
      ..where((s) => s.createdAt.isSmallerThanValue(end))
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)]))
        .get();
  }

  Future<List<SaleItem>> getSaleItems(String saleId) async {
    return await (db.select(db.saleItems)
      ..where((si) => si.saleId.equals(saleId)))
        .get();
  }

  Future<Product?> getProduct(String productId) async {
    return await (db.select(db.products)
      ..where((p) => p.id.equals(productId)))
        .getSingleOrNull();
  }

  // ═══ Expenses ═══

  Future<Map<String, int>> getExpenseSummary(
      DateTime start, DateTime end) async {
    // Real cash out.
    final paidQuery = db.customSelect(
      '''
      SELECT COALESCE(SUM(paid_amount_minor), 0) AS total
      FROM expenses
      WHERE business_id = ?
      AND created_at >= ? AND created_at < ?
      ''',
      variables: [
        Variable.withString(businessId),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {db.expenses},
    );
    final paidRow = await paidQuery.getSingleOrNull();
    final paid = paidRow?.read<int?>('total') ?? 0;

    // Remaining balance on anything not fully paid.
    final pendingQuery = db.customSelect(
      '''
      SELECT COALESCE(SUM(amount_minor - paid_amount_minor), 0) AS total
      FROM expenses
      WHERE business_id = ? AND status != 'paid'
      AND created_at >= ? AND created_at < ?
      ''',
      variables: [
        Variable.withString(businessId),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {db.expenses},
    );
    final pendingRow = await pendingQuery.getSingleOrNull();
    final pending = pendingRow?.read<int?>('total') ?? 0;

    return {'paid': paid, 'pending': pending};
  }

  // ═══ Held orders ═══

  Future<List<HeldOrder>> getHeldOrders() async {
    return await (db.select(db.heldOrders)
      ..where((h) => h.businessId.equals(businessId))
      ..orderBy([(h) => OrderingTerm.desc(h.createdAt)]))
        .get();
  }

  Future<int> getHeldOrdersCount() async {
    final result = await db.customSelect(
      'SELECT COUNT(*) as cnt FROM held_orders WHERE business_id = ?',
      variables: [Variable.withString(businessId)],
      readsFrom: {db.heldOrders},
    ).getSingle();
    return result.read<int?>('cnt') ?? 0;
  }

  // ═══ Payment method totals (split payments) ═══

  /// Aggregate totals per payment method for a given period.
  ///
  /// Reads from `sale_payments`, which stores one row per split component.
  /// For legacy sales that predate the split table, the schema-9 migration
  /// backfilled one row per sale so this always returns complete totals.
  ///
  /// Returns a map with keys `'cash'` and `'mpesa'`, both always present
  /// (defaulting to `0` when there were no transactions of that method).
  Future<Map<String, int>> getPaymentMethodTotals(
      DateTime start,
      DateTime end,
      ) async {
    final rows = await db.customSelect(
      '''
      SELECT sp.method AS method, COALESCE(SUM(sp.amount_minor), 0) AS total
      FROM sale_payments sp
      JOIN sales s ON s.id = sp.sale_id
      WHERE s.business_id = ? AND s.status = 'completed'
        AND s.created_at >= ? AND s.created_at < ?
      GROUP BY sp.method
      ''',
      variables: [
        Variable.withString(businessId),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {db.salePayments, db.sales},
    ).get();

    final result = <String, int>{'cash': 0, 'mpesa': 0};
    for (final row in rows) {
      final method = row.read<String>('method');
      final total = row.read<int?>('total') ?? 0;
      result[method] = (result[method] ?? 0) + total;
    }
    return result;
  }

  /// Per-sale split breakdown, used by the Reports screen's transaction
  /// tiles and by the new `TransactionsScreen`.
  Future<List<SalePayment>> getSalePayments(String saleId) async {
    return await (db.select(db.salePayments)
      ..where((t) => t.saleId.equals(saleId)))
        .get();
  }
}