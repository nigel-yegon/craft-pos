import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../database/app_database.dart';

class ReportProvider extends ChangeNotifier {
  final AppDatabase db;
  final String businessId;
  ReportProvider(this.db, this.businessId);

  /// Existing daily summary
  Future<Map<String, int>> getDailySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _getSummary(start, end);
  }

  /// NEW: Weekly summary (last 7 days)
  Future<Map<String, int>> getWeeklySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return _getSummary(start, end);
  }

  /// NEW: Monthly summary (last 30 days)
  Future<Map<String, int>> getMonthlySummary() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29));
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return _getSummary(start, end);
  }

  /// NEW: Get 7-day sales trend for the chart
  Future<List<Map<String, dynamic>>> getSalesTrend() async {
    final now = DateTime.now();
    final result = <Map<String, dynamic>>[];

    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
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

  /// NEW: Fetch all sales in a date range for PDF
  Future<List<Sale>> getSalesInRange(DateTime start, DateTime end) async {
    return await (db.select(db.sales)
      ..where((s) => s.businessId.equals(businessId))
      ..where((s) => s.status.equals('completed'))
      ..where((s) => s.createdAt.isBiggerOrEqualValue(start))
      ..where((s) => s.createdAt.isSmallerThanValue(end)))
        .get();
  }

  /// Internal helper
  Future<Map<String, int>> _getSummary(DateTime start, DateTime end) async {
    final salesQuery = db.select(db.sales)
      ..where((s) => s.businessId.equals(businessId))
      ..where((s) => s.status.equals('completed'))
      ..where((s) => s.createdAt.isBiggerOrEqualValue(start))
      ..where((s) => s.createdAt.isSmallerThanValue(end));

    final sales = await salesQuery.get();
    final totalSales = sales.fold<int>(0, (sum, s) => sum + s.totalAmountMinor);

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
    final totalProfit = (profitResult?.read<double?>('profit') ?? 0).round();

    final stockValueQuery = db.customSelect(
      '''
      SELECT SUM(sm.total_qty * p.cost_price_minor) as total_value
      FROM (
        SELECT product_id, SUM(quantity_milli) as total_qty
        FROM stock_movements GROUP BY product_id
      ) sm
      JOIN products p ON p.id = sm.product_id
      WHERE p.business_id = ? AND p.is_active = 1
      ''',
      variables: [Variable.withString(businessId)],
      readsFrom: {db.products, db.stockMovements},
    );
    final stockResult = await stockValueQuery.getSingleOrNull();
    final totalStockValue = ((stockResult?.read<int?>('total_value') ?? 0) ~/ 1000);

    return {
      'sales': totalSales,
      'profit': totalProfit,
      'stockValue': totalStockValue,
    };
  }
}