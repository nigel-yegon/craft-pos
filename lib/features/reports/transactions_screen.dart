// lib/features/reports/transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/report_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/pdf_helper.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  final ReportProvider provider;
  const TransactionsScreen({super.key, required this.provider});

  @override
  ConsumerState<TransactionsScreen> createState() =>
      _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _search = '';

  // Filter state (mirrors StockReportScreen's ledger filters).
  String? _filterMethod;
  String _filterPeriod = 'all';
  DateTimeRange? _filterDateRange;

  // Cached names + line items + splits to avoid repeated queries.
  final Map<String, String> _productNameCache = {};
  final Map<String, List<_Line>> _lineCache = {};
  final Map<String, List<SalePayment>> _paymentCache = {};

  // Full list loaded once; filtered in-memory.
  List<Sale> _allSales = const [];

  // Export state.
  bool _isExporting = false;

  bool get _hasActiveFilters =>
      _filterMethod != null ||
          _filterPeriod != 'all' ||
          _filterDateRange != null ||
          _search.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _filterMethod = null;
      _filterPeriod = 'all';
      _filterDateRange = null;
      _search = '';
    });
  }

  String _filterDescription() {
    final parts = <String>[];
    if (_filterMethod != null) {
      parts.add('Method: ${_prettyMethod(_filterMethod!)}');
    }
    if (_filterPeriod != 'all') {
      parts.add('Period: ${_filterPeriod == 'today' ? 'Today' : 'This Week'}');
    }
    if (_filterDateRange != null) {
      final fmt = DateFormat('dd/MM/yyyy');
      parts.add(
        'Date: ${fmt.format(_filterDateRange!.start)} - '
            '${fmt.format(_filterDateRange!.end)}',
      );
    }
    if (_search.isNotEmpty) parts.add('Search: "$_search"');
    return parts.isEmpty ? 'All transactions' : parts.join(' • ');
  }

  String _prettyMethod(String m) {
    switch (m) {
      case 'cash':
        return 'Cash';
      case 'mpesa':
        return 'M-Pesa';
      case 'cash+mpesa':
        return 'Cash + M-Pesa';
      default:
        return m;
    }
  }

  String _formatKsh(int minorUnits) =>
      'KSh ${(minorUnits / 100).toStringAsFixed(2)}';

  // ═══════════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final db = ref.read(databaseProvider);
    final rows = await (db.select(db.sales)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
    if (!mounted) return;
    setState(() => _allSales = rows);
  }

  Future<List<_Line>> _loadLines(String saleId) async {
    if (_lineCache.containsKey(saleId)) return _lineCache[saleId]!;
    final db = ref.read(databaseProvider);
    final items = await (db.select(db.saleItems)
      ..where((t) => t.saleId.equals(saleId)))
        .get();

    final lines = <_Line>[];
    for (final item in items) {
      if (!_productNameCache.containsKey(item.productId)) {
        final p = await (db.select(db.products)
          ..where((t) => t.id.equals(item.productId)))
            .getSingleOrNull();
        _productNameCache[item.productId] =
            p?.name ?? '(deleted product)';
      }
      lines.add(_Line(
        productName: _productNameCache[item.productId]!,
        quantityMilli: item.quantityMilli,
        unitPriceMinor: item.unitPriceMinor,
        lineTotalMinor: item.lineTotalMinor,
      ));
    }
    _lineCache[saleId] = lines;
    return lines;
  }

  Future<List<SalePayment>> _loadPayments(String saleId) async {
    if (_paymentCache.containsKey(saleId)) return _paymentCache[saleId]!;
    final db = ref.read(databaseProvider);
    final rows = await (db.select(db.salePayments)
      ..where((t) => t.saleId.equals(saleId)))
        .get();
    _paymentCache[saleId] = rows;
    return rows;
  }

  // ═══════════════════════════════════════════════════════════════════
  // EXPORT PDF (only entry point for the transactions PDF)
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _exportFilteredPdf() async {
    if (_isExporting) return;

    final filtered = _filteredSales();
    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text('Nothing to export — no transactions match the filters.'),
          backgroundColor: AppTheme.burntOrange,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      // Preload split-payment rows for each filtered sale so the PDF can
      // include the breakdown in one pass.
      final breakdown = <String, List<SalePayment>>{};
      for (final sale in filtered) {
        breakdown[sale.id] = await _loadPayments(sale.id);
      }

      final db = ref.read(databaseProvider);
      final biz = await db.select(db.businesses).getSingleOrNull();
      final businessName = biz?.name ?? 'My Shop';

      await PdfHelper.generateTransactionsReport(
        businessName: businessName,
        sales: filtered,
        filterDescription: _filterDescription(),
        generatedAt: DateTime.now(),
        paymentBreakdown: breakdown,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: AppTheme.burntOrange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // FILTER LOGIC
  // ═══════════════════════════════════════════════════════════════════

  List<Sale> _filteredSales() {
    return _allSales.where((s) {
      final method = (s.paymentMethod ?? '').toLowerCase();
      final amount = _formatKsh(s.totalAmountMinor).toLowerCase();
      final dateLabel = DateFormat('dd MMM yyyy HH:mm')
          .format(s.createdAt)
          .toLowerCase();

      final matchesSearch = _search.isEmpty ||
          amount.contains(_search) ||
          method.contains(_search) ||
          dateLabel.contains(_search);

      final matchesMethod =
          _filterMethod == null || method == _filterMethod;

      bool matchesPeriod = true;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      if (_filterPeriod == 'today') {
        matchesPeriod = s.createdAt.isAfter(todayStart);
      } else if (_filterPeriod == 'week') {
        final weekStart = todayStart.subtract(const Duration(days: 7));
        matchesPeriod = s.createdAt.isAfter(weekStart);
      }

      bool matchesDateRange = true;
      if (_filterDateRange != null) {
        matchesDateRange = !s.createdAt.isBefore(_filterDateRange!.start) &&
            !s.createdAt
                .isAfter(_filterDateRange!.end.add(const Duration(days: 1)));
      }

      return matchesSearch &&
          matchesMethod &&
          matchesPeriod &&
          matchesDateRange;
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // FILTER SHEET
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      initialDateRange: _filterDateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: AppTheme.heroGreen,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _filterDateRange = picked);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter Transactions',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      TextButton(
                        onPressed: () {
                          setModalState(_clearFilters);
                        },
                        child: const Text('Reset',
                            style: TextStyle(color: AppTheme.burntOrange)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Payment Method',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildMethodChip('All Methods', null, setModalState),
                      _buildMethodChip('Cash', 'cash', setModalState),
                      _buildMethodChip('M-Pesa', 'mpesa', setModalState),
                      _buildMethodChip(
                          'Cash + M-Pesa', 'cash+mpesa', setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Time Period',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildPeriodChip('All Time', 'all', setModalState),
                      _buildPeriodChip('Today', 'today', setModalState),
                      _buildPeriodChip('This Week', 'week', setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Custom Date Range',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      Navigator.pop(context);
                      await _pickDateRange();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.softMint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month,
                              color: AppTheme.heroGreen, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _filterDateRange == null
                                  ? 'Select date range'
                                  : '${DateFormat('dd MMM yyyy').format(_filterDateRange!.start)} – '
                                  '${DateFormat('dd MMM yyyy').format(_filterDateRange!.end)}',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.inkBlack),
                            ),
                          ),
                          if (_filterDateRange != null)
                            GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  _filterDateRange = null;
                                });
                                setState(() {});
                              },
                              child: const Icon(Icons.close,
                                  size: 18, color: AppTheme.onLightMuted),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMethodChip(
      String label, String? value, StateSetter setModalState) {
    final isSelected = _filterMethod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          _filterMethod = selected ? value : null;
        });
        setState(() {});
      },
      selectedColor: AppTheme.heroGreen.withValues(alpha: 0.1),
      checkmarkColor: AppTheme.heroGreen,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.heroGreen : AppTheme.inkBlack,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _buildPeriodChip(
      String label, String value, StateSetter setModalState) {
    final isSelected = _filterPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          _filterPeriod = value;
        });
        setState(() {});
      },
      selectedColor: AppTheme.heroGreen.withValues(alpha: 0.1),
      checkmarkColor: AppTheme.heroGreen,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.heroGreen : AppTheme.inkBlack,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSales();
    final totalMinor =
    filtered.fold<int>(0, (s, t) => s + t.totalAmountMinor);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.inkBlack),
          onPressed: () => Navigator.pop(context),
        ),
        // ⭐ Export PDF — the only entry point for the transactions PDF.
        actions: [
          TextButton.icon(
            onPressed: _isExporting ? null : _exportFilteredPdf,
            icon: _isExporting
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.heroGreen,
              ),
            )
                : const Icon(Icons.picture_as_pdf,
                color: AppTheme.heroGreen, size: 20),
            label: Text(
              _isExporting ? 'Exporting…' : 'Export PDF',
              style: const TextStyle(
                color: AppTheme.heroGreen,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ─── Search + filter ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search amount, method, or date...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) =>
                        setState(() => _search = v.toLowerCase()),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showFilterSheet,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.softMint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child:
                    const Icon(Icons.tune, color: AppTheme.heroGreen),
                  ),
                ),
              ],
            ),
          ),

          // ─── Filter summary bar ───────────────────────────────────
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt,
                      size: 14, color: AppTheme.heroGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _filterDescription(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.heroGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearFilters,
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.burntOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ─── Summary strip ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.midGreen, AppTheme.heroGreen],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _summaryItem('COUNT', '${filtered.length}'),
                  _summaryItem('TOTAL', _formatKsh(totalMinor)),
                ],
              ),
            ),
          ),

          // ─── List ────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? const Center(
              child: Text('No transactions match your filters.',
                  style: TextStyle(color: AppTheme.onLightMuted)),
            )
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppTheme.inkBlack.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, index) {
                return _buildSaleTile(filtered[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSaleTile(Sale sale) {
    final isSplit = (sale.paymentMethod ?? '').contains('+');

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppTheme.softMint,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.receipt_long,
              color: AppTheme.heroGreen, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _formatKsh(sale.totalAmountMinor),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppTheme.inkBlack,
                ),
              ),
            ),
            Text(
              _prettyMethod(sale.paymentMethod ?? 'cash'),
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.onLightMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            DateFormat('dd MMM yyyy, HH:mm').format(sale.createdAt),
            style: const TextStyle(
                fontSize: 11, color: AppTheme.onLightMuted),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FutureBuilder<List<_Line>>(
              future: _loadLines(sale.id),
              builder: (context, snap) {
                if (!snap.hasData) {
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
                final lines = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Items',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppTheme.onLightSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...lines.map(_buildLineRow),
                    if (isSplit) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Paid with',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppTheme.onLightSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FutureBuilder<List<SalePayment>>(
                        future: _loadPayments(sale.id),
                        builder: (context, snap) {
                          if (!snap.hasData) return const SizedBox();
                          return Column(
                            children: snap.data!
                                .map((p) => _buildPaymentRow(p))
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineRow(_Line line) {
    final qty = line.quantityMilli / 1000.0;
    final qtyLabel = qty % 1 == 0
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(line.productName,
                style: const TextStyle(fontSize: 13)),
          ),
          Text(
            '$qtyLabel × ${_formatKsh(line.unitPriceMinor)}',
            style: const TextStyle(
                fontSize: 12, color: AppTheme.onLightMuted),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              _formatKsh(line.lineTotalMinor),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(SalePayment p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            p.method == 'cash' ? Icons.money : Icons.phone_android,
            size: 14,
            color: AppTheme.heroGreen,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _prettyMethod(p.method),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (p.reference != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                p.reference!,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.onLightMuted),
              ),
            ),
          Text(
            _formatKsh(p.amountMinor),
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// INTERNAL MODELS
// ═══════════════════════════════════════════════════════════════════

class _Line {
  final String productName;
  final int quantityMilli;
  final int unitPriceMinor;
  final int lineTotalMinor;

  _Line({
    required this.productName,
    required this.quantityMilli,
    required this.unitPriceMinor,
    required this.lineTotalMinor,
  });
}