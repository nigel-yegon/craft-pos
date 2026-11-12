import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/report_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pdf_helper.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final ReportProvider provider;
  const ReportsScreen({super.key, required this.provider});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, int> _summary = {};
  List<Map<String, dynamic>> _trend = [];
  List<Sale> _salesInRange = [];
  List<HeldOrder> _heldOrders = [];
  final Map<String, List<_SaleLine>> _lineCache = {};
  bool _isLoading = true;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  String _periodLabel = 'Today';
  String _businessName = 'My Shop';

  int _expensePaid = 0;
  int _expensePending = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadBusinessName();
    _loadData(0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBusinessName() async {
    final db = ref.read(databaseProvider);
    final biz = await db.select(db.businesses).getSingleOrNull();
    if (biz != null && mounted) {
      setState(() => _businessName = biz.name);
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _loadData(_tabController.index);
    }
  }

  Future<void> _loadData(int tabIndex) async {
    setState(() => _isLoading = true);
    _lineCache.clear();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Map<String, int> summary;
    List<Map<String, dynamic>> trend;
    List<Sale> sales;
    List<HeldOrder> held;

    if (tabIndex == 0) {
      summary = await widget.provider.getDailySummary();
      trend = await widget.provider.getSalesTrend();
      _start = today;
      _end = today.add(const Duration(days: 1));
      _periodLabel = 'Today';
    } else if (tabIndex == 1) {
      summary = await widget.provider.getWeeklySummary();
      trend = await widget.provider.getSalesTrend();
      _start = today.subtract(const Duration(days: 6));
      _end = today.add(const Duration(days: 1));
      _periodLabel = 'Last 7 Days';
    } else {
      summary = await widget.provider.getMonthlySummary();
      trend = await widget.provider.getSalesTrend();
      _start = today.subtract(const Duration(days: 29));
      _end = today.add(const Duration(days: 1));
      _periodLabel = 'Last 30 Days';
    }

    sales = await widget.provider.getSalesInRange(_start, _end);
    held = await widget.provider.getHeldOrders();

    final expenseSummary =
    await widget.provider.getExpenseSummary(_start, _end);

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _trend = trend;
      _salesInRange = sales;
      _heldOrders = held;
      _expensePaid = expenseSummary['paid'] ?? 0;
      _expensePending = expenseSummary['pending'] ?? 0;
      _isLoading = false;
    });
  }

  Future<List<_SaleLine>> _loadSaleLines(String saleId) async {
    if (_lineCache.containsKey(saleId)) return _lineCache[saleId]!;

    final items = await widget.provider.getSaleItems(saleId);
    final lines = <_SaleLine>[];

    for (final item in items) {
      final product = await widget.provider.getProduct(item.productId);
      lines.add(_SaleLine(
        productName: product?.name ?? '(deleted product)',
        quantity: item.quantityMilli / 1000.0,
        unitPriceMinor: item.unitPriceMinor,
        lineTotalMinor: item.lineTotalMinor,
      ));
    }

    _lineCache[saleId] = lines;
    return lines;
  }

  Future<void> _exportPdf() async {
    await PdfHelper.generateSalesReport(
      businessName: _businessName,
      sales: _salesInRange,
      summary: _summary,
      start: _start,
      end: _end,
    );
  }

  String _formatKsh(int minorUnits) =>
      'KSh ${(minorUnits / 100).toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_businessName.isNotEmpty ? _businessName : 'Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf,
                color: AppTheme.primaryGreen),
            tooltip: 'Export PDF',
            onPressed: _isLoading ? null : _exportPdf,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textLight,
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: () => _loadData(_tabController.index),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Period: $_periodLabel',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // ─── Metric cards 2×2 ───
              Row(
                children: [
                  _buildMetricCard(
                    'Sales',
                    _formatKsh(_summary['sales'] ?? 0),
                    AppTheme.primaryGreen,
                    Icons.attach_money,
                  ),
                  const SizedBox(width: 12),
                  _buildMetricCard(
                    'Profit',
                    _formatKsh(_summary['profit'] ?? 0),
                    Colors.blue,
                    Icons.trending_up,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildMetricCard(
                    'Stock Value',
                    _formatKsh(_summary['stockValue'] ?? 0),
                    Colors.orange,
                    Icons.inventory,
                  ),
                  const SizedBox(width: 12),
                  _buildMetricCard(
                    'Transactions',
                    '${_salesInRange.length}',
                    Colors.purple,
                    Icons.receipt_long,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ─── Money Position ───
              _buildMoneyPositionCard(),
              const SizedBox(height: 24),

              // ─── Held orders ───
              if (_heldOrders.isNotEmpty) ...[
                Card(
                  color: Colors.orange.withValues(alpha: 0.1),
                  child: ListTile(
                    leading: const Icon(Icons.pause_circle_outline,
                        color: Colors.orange),
                    title: Text(
                      '${_heldOrders.length} held order(s) awaiting payment',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    subtitle: const Text(
                      'Go to Sales → Held Orders to resume',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ─── Sales trend chart ───
              const Text(
                'Sales Trend (Last 7 Days)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(height: 220, child: _buildChart()),
                ),
              ),
              const SizedBox(height: 24),

              // ─── Transactions ───
              const Text(
                'Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 12),
              if (_salesInRange.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No transactions for this period',
                        style: TextStyle(color: AppTheme.textLight),
                      ),
                    ),
                  ),
                )
              else
                ..._salesInRange.take(20).map(_buildTransactionTile),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Money Position card ───
  Widget _buildMoneyPositionCard() {
    final sales = _summary['sales'] ?? 0;
    final net = sales - _expensePaid;

    return Card(
      color: AppTheme.primaryGreen.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Money Position',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),
            _positionRow(
              'Money In (Sales)',
              _formatKsh(sales),
              Colors.green,
            ),
            _positionRow(
              'Money Out (Paid)',
              '- ${_formatKsh(_expensePaid)}',
              Colors.red,
            ),
            _positionRow(
              'Pending Balances',
              _formatKsh(_expensePending),
              Colors.orange,
              sub: true,
            ),
            const Divider(),
            _positionRow(
              'Net Position',
              _formatKsh(net),
              AppTheme.primaryGreen,
              bold: true,
            ),
            const SizedBox(height: 4),
            Text(
              net >= 0
                  ? 'You are cash-positive for this period.'
                  : 'You are cash-negative for this period.',
              style: TextStyle(
                fontSize: 11,
                color: net >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionRow(String label, String value, Color color,
      {bool bold = false, bool sub = false}) {
    return Padding(
      padding: EdgeInsets.only(top: sub ? 2 : 8, left: sub ? 16 : 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: sub ? 12 : 13,
              color: sub ? AppTheme.textLight : AppTheme.textDark,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Transaction tile ───
  Widget _buildTransactionTile(Sale sale) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.receipt,
            color: AppTheme.primaryGreen,
            size: 20,
          ),
        ),
        title: Text(
          DateFormat('dd MMM, HH:mm').format(sale.createdAt),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          sale.paymentMethod ?? 'Unknown',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          _formatKsh(sale.totalAmountMinor),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          FutureBuilder<List<_SaleLine>>(
            future: _loadSaleLines(sale.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final lines = snapshot.data!;
              if (lines.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No line items recorded.'),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items sold',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...lines.map((line) {
                    final qty = line.quantity;
                    final qtyLabel = qty % 1 == 0
                        ? qty.toStringAsFixed(0)
                        : qty.toStringAsFixed(2);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              line.productName,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '$qtyLabel × ${_formatKsh(line.unitPriceMinor)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textLight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            child: Text(
                              _formatKsh(line.lineTotalMinor),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Metric card ───
  Widget _buildMetricCard(
      String title,
      String value,
      Color color,
      IconData icon,
      ) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textLight)),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Sales trend chart ───
  Widget _buildChart() {
    if (_trend.isEmpty) return const Center(child: Text('No data'));

    final maxY = _trend
        .map((e) => (e['total'] as int) / 100.0)
        .reduce((a, b) => a > b ? a : b) *
        1.2;
    final safeMaxY = maxY < 100 ? 100.0 : maxY;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: safeMaxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: safeMaxY / 4,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}',
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textLight),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= _trend.length) {
                  return const SizedBox();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _trend[index]['label'],
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textLight),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: _trend.asMap().entries.map((entry) {
          final index = entry.key;
          final total = (entry.value['total'] as int) / 100.0;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: total,
                color: AppTheme.primaryGreen,
                width: 18,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _SaleLine {
  final String productName;
  final double quantity;
  final int unitPriceMinor;
  final int lineTotalMinor;

  _SaleLine({
    required this.productName,
    required this.quantity,
    required this.unitPriceMinor,
    required this.lineTotalMinor,
  });
}