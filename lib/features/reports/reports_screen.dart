import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/report_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pdf_helper.dart';
import '../../core/widgets/currency_icon.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_businessName.isNotEmpty ? _businessName : 'Reports'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf,
                color: AppTheme.heroGreen),
            tooltip: 'Export PDF',
            onPressed: _isLoading ? null : _exportPdf,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.heroGreen,
          indicatorWeight: 3,
          labelColor: AppTheme.heroGreen,
          unselectedLabelColor: AppTheme.onLightMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Today'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.heroGreen))
          : RefreshIndicator(
        onRefresh: () => _loadData(_tabController.index),
        color: AppTheme.heroGreen,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Period: $_periodLabel',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onLightMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              // ─── Summary cards 2×2 ───
              Row(
                children: [
                  _buildMetricCard(
                    'Sales',
                    _formatKsh(_summary['sales'] ?? 0),
                    AppTheme.heroGreen, // Dark Forest
                    const CurrencyIcon(color: Colors.white, size: 20),
                    isDark: true,
                  ),
                  const SizedBox(width: 12),
                  _buildMetricCard(
                    'Profit',
                    _formatKsh(_summary['profit'] ?? 0),
                    AppTheme.midGreen, // Mid Green
                    const Icon(Icons.trending_up,
                        size: 20, color: Colors.white),
                    isDark: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildMetricCard(
                    'Stock Value',
                    _formatKsh(_summary['stockValue'] ?? 0),
                    AppTheme.forestDeep, // Darker Green
                    const Icon(Icons.inventory,
                        size: 20, color: Colors.white),
                    isDark: true,
                  ),
                  const SizedBox(width: 12),
                  _buildMetricCard(
                    'Transactions',
                    '${_salesInRange.length}',
                    AppTheme.midnightViolet, // Deep Violet
                    const Icon(Icons.receipt_long,
                        size: 20, color: Colors.white),
                    isDark: true,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Money Position Card ───
              _buildMoneyPositionCard(),
              const SizedBox(height: 24),

              // ─── Held orders alert ───
              if (_heldOrders.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.burntOrange.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.burntOrange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.pause_circle_outline,
                          color: AppTheme.burntOrange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_heldOrders.length} held order(s)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.inkBlack,
                              ),
                            ),
                            const Text(
                              'Awaiting payment. Go to Sales → Held Orders.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.onLightSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // ─── Sales trend chart ───
              const Text(
                'Sales Trend (Last 7 Days)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkBlack,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.inkBlack.withValues(alpha: 0.06)),
                ),
                child: SizedBox(height: 220, child: _buildChart()),
              ),
              const SizedBox(height: 24),

              // ─── Transactions ───
              const Text(
                'Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.inkBlack,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              if (_salesInRange.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.inkBlack.withValues(alpha: 0.06)),
                  ),
                  child: const Center(
                    child: Text(
                      'No transactions for this period',
                      style: TextStyle(color: AppTheme.onLightMuted),
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

  // ─── Money Position Card (Dark Theme) ───
  Widget _buildMoneyPositionCard() {
    final sales = _summary['sales'] ?? 0;
    final net = sales - _expensePaid;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.heroGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.heroGreen.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MONEY POSITION',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 1.2,
              color: AppTheme.onHeroMuted,
            ),
          ),
          const SizedBox(height: 16),
          _positionRow(
            'Money In (Sales)',
            _formatKsh(sales),
            AppTheme.brightGreen,
          ),
          _positionRow(
            'Money Out (Paid)',
            '- ${_formatKsh(_expensePaid)}',
            Colors.white,
          ),
          _positionRow(
            'Pending Balances',
            _formatKsh(_expensePending),
            AppTheme.onHeroSecondary,
            sub: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              color: Colors.white.withValues(alpha: 0.1),
              height: 1,
            ),
          ),
          _positionRow(
            'Net Position',
            _formatKsh(net),
            net >= 0 ? AppTheme.brightGreen : AppTheme.burntOrange,
            bold: true,
          ),
          const SizedBox(height: 8),
          Text(
            net >= 0
                ? 'You are cash-positive for this period.'
                : 'You are cash-negative for this period.',
            style: TextStyle(
              fontSize: 11,
              color: net >= 0 ? AppTheme.brightGreen : AppTheme.burntOrange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
              color: sub ? AppTheme.onHeroMuted : Colors.white,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: bold ? -0.5 : 0,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Transaction Tile (Clean White) ───
  Widget _buildTransactionTile(Sale sale) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.inkBlack.withValues(alpha: 0.08)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.softMint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.receipt,
              color: AppTheme.heroGreen,
              size: 20,
            ),
          ),
          title: Text(
            DateFormat('dd MMM, HH:mm').format(sale.createdAt),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppTheme.inkBlack,
            ),
          ),
          subtitle: Text(
            sale.paymentMethod ?? 'Unknown',
            style: const TextStyle(fontSize: 12, color: AppTheme.onLightMuted),
          ),
          trailing: Text(
            _formatKsh(sale.totalAmountMinor),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.inkBlack,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Divider(color: AppTheme.inkBlack.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 12),
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
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppTheme.onLightSecondary,
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
                                color: AppTheme.onLightMuted,
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 90,
                              child: Text(
                                _formatKsh(line.lineTotalMinor),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
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
      ),
    );
  }

  // ─── Metric Card (Dark Themed) ───
  Widget _buildMetricCard(
      String title,
      String value,
      Color bgColor,
      Widget iconWidget, {
        bool isDark = false,
      }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                iconWidget,
                Icon(Icons.arrow_outward,
                    size: 14, color: Colors.white.withValues(alpha: 0.4)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sales Trend Chart ───
  Widget _buildChart() {
    if (_trend.isEmpty) {
      return const Center(
        child: Text('No data', style: TextStyle(color: AppTheme.onLightMuted)),
      );
    }

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
              FlLine(color: AppTheme.inkBlack.withValues(alpha: 0.05), strokeWidth: 1),
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
                    fontSize: 10, color: AppTheme.onLightMuted),
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
                        fontSize: 10, color: AppTheme.onLightMuted),
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
                color: AppTheme.brightGreen, // Bright green bars
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
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