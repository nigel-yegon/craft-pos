import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/product_provider.dart';
import '../../core/theme/app_theme.dart';

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // If using Riverpod for business name
import '../../core/providers/database_provider.dart'; // To get business name
import '../../core/utils/pdf_helper.dart'; // To call the export

class StockReportScreen extends StatefulWidget {
  final ProductProvider provider;
  const StockReportScreen({super.key, required this.provider});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _search = '';

  // ⭐ Filter State
  String? _filterType; // e.g., 'purchase', 'sale', 'adjustment'
  String _filterPeriod = 'all'; // 'today', 'week', 'all'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _exportPdf() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stock Report PDF export coming soon.'),
        backgroundColor: AppTheme.heroGreen,
      ),
    );
  }

  // ⭐ Open Filter Bottom Sheet
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Ledger',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _filterType = null;
                            _filterPeriod = 'all';
                          });
                          setState(() {});
                        },
                        child: const Text('Reset',
                            style: TextStyle(color: AppTheme.burntOrange)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Type Filter
                  const Text('Transaction Type',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterChip('All Types', null, setModalState),
                      _buildFilterChip('Purchases', 'purchase', setModalState),
                      _buildFilterChip('Sales', 'sale', setModalState),
                      _buildFilterChip(
                          'Adjustments', 'adjustment', setModalState),
                      _buildFilterChip('Damage', 'damage', setModalState),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Period Filter
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

  Widget _buildFilterChip(
      String label, String? value, StateSetter setModalState) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          _filterType = selected ? value : null;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Stock Report'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.inkBlack),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _exportPdf,
            icon: const Icon(Icons.picture_as_pdf,
                color: AppTheme.heroGreen, size: 20),
            label: const Text(
              'Export PDF',
              style: TextStyle(
                color: AppTheme.heroGreen,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.brightGreen,
          labelColor: AppTheme.inkBlack,
          unselectedLabelColor: AppTheme.onLightMuted,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Ledger'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSummaryTab(),
          _buildLedgerTab(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 1: SUMMARY
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSummaryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.provider.getStockSummary(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;

        if (rows.isEmpty) {
          return const Center(
            child: Text('No products yet.',
                style: TextStyle(color: AppTheme.onLightMuted)),
          );
        }

        int grandIn = 0, grandOut = 0, grandBalance = 0;
        int grandValueMinor = 0;
        for (final r in rows) {
          grandIn += r['totalIn'] as int;
          grandOut += r['totalOut'] as int;
          grandBalance += r['balance'] as int;
          grandValueMinor += r['valueMinor'] as int;
        }
        final grandValue = grandValueMinor / 100.0;

        return Column(
          children: [
            // ─── Totals card ───
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.midGreen, AppTheme.heroGreen],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.heroGreen.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _totalsItem(
                        'STOCK IN', (grandIn / 1000).toStringAsFixed(0)),
                    _totalsItem(
                        'STOCK OUT', (grandOut / 1000).toStringAsFixed(0)),
                    _totalsItem(
                        'BALANCE', (grandBalance / 1000).toStringAsFixed(0)),
                    _totalsItem(
                        'VALUE', 'KSh ${grandValue.toStringAsFixed(0)}'),
                  ],
                ),
              ),
            ),

            // ─── Product list ───
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: rows.length,
                separatorBuilder: (_, __) => Divider(
                  height: 24,
                  color: AppTheme.inkBlack.withValues(alpha: 0.06),
                ),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final p = row['product'] as Product;
                  final totalIn = row['totalIn'] as int;
                  final totalOut = row['totalOut'] as int;
                  final balance = row['balance'] as int;
                  final avgCostMinor = row['avgCostMinor'] as int;
                  final valueMinor = row['valueMinor'] as int;
                  final isLow = row['isLow'] as bool;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: AppTheme.inkBlack,
                                ),
                              ),
                            ),
                            Text(
                              (balance / 1000).toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: isLow
                                    ? AppTheme.burntOrange
                                    : AppTheme.heroGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _smallChip(
                              '+${(totalIn / 1000).toStringAsFixed(0)}',
                              AppTheme.brightGreen,
                            ),
                            const SizedBox(width: 6),
                            _smallChip(
                              '-${(totalOut / 1000).toStringAsFixed(0)}',
                              AppTheme.midGreen,
                            ),
                            const SizedBox(width: 8),
                            if (isLow)
                              const Text(
                                'LOW STOCK',
                                style: TextStyle(
                                  color: AppTheme.burntOrange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            const Spacer(),
                            Text(
                              'Avg: KSh ${(avgCostMinor / 100).toStringAsFixed(2)} • '
                                  'Val: KSh ${(valueMinor / 100).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.onLightMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _totalsItem(String label, String value) {
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
            fontSize: 16,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _smallChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 2: LEDGER
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildLedgerTab() {
    return Column(
      children: [
        // ⭐ Search & Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by product, note, or type...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
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
                  child: const Icon(Icons.tune, color: AppTheme.heroGreen),
                ),
              ),
            ],
          ),
        ),

        // Active filter indicator
        if (_filterType != null || _filterPeriod != 'all')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.filter_alt, size: 14, color: AppTheme.heroGreen),
                const SizedBox(width: 6),
                Text(
                  'Filters active',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.heroGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _filterType = null;
                      _filterPeriod = 'all';
                    });
                  },
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

        Expanded(
          child: StreamBuilder<List<StockMovement>>(
            stream: widget.provider.stockLedgerStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final movements = snapshot.data!;
              if (movements.isEmpty) {
                return const Center(
                  child: Text('No stock movements recorded yet.',
                      style: TextStyle(color: AppTheme.onLightMuted)),
                );
              }

              return FutureBuilder<Map<String, String>>(
                future: _loadProductNames(movements),
                builder: (context, nameSnapshot) {
                  final names = nameSnapshot.data ?? {};

                  final filtered = movements.where((m) {
                    // 1. Text Search Filter
                    final name = (names[m.productId] ?? '').toLowerCase();
                    final note = (m.note ?? '').toLowerCase();
                    final type = m.type.toLowerCase();
                    final matchesSearch = name.contains(_search) ||
                        note.contains(_search) ||
                        type.contains(_search);

                    // 2. Type Filter
                    final matchesType = _filterType == null || m.type == _filterType;

                    // 3. Period Filter
                    bool matchesPeriod = true;
                    final now = DateTime.now();
                    final todayStart = DateTime(now.year, now.month, now.day);

                    if (_filterPeriod == 'today') {
                      matchesPeriod = m.createdAt.isAfter(todayStart);
                    } else if (_filterPeriod == 'week') {
                      final weekStart = todayStart.subtract(const Duration(days: 7));
                      matchesPeriod = m.createdAt.isAfter(weekStart);
                    }

                    return matchesSearch && matchesType && matchesPeriod;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No movements match your filters.',
                          style: TextStyle(color: AppTheme.onLightMuted)),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: AppTheme.inkBlack.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      final m = filtered[index];
                      final isIn = m.quantityMilli > 0;
                      final productName = names[m.productId] ?? '(deleted)';
                      final qty = (m.quantityMilli / 1000).toStringAsFixed(
                          m.quantityMilli % 1000 == 0 ? 0 : 2);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (isIn
                                ? AppTheme.brightGreen
                                : AppTheme.burntOrange)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isIn
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isIn
                                ? AppTheme.heroGreen
                                : AppTheme.burntOrange,
                            size: 18,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppTheme.inkBlack),
                              ),
                            ),
                            Text(
                              '${isIn ? '+' : ''}$qty',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isIn
                                    ? AppTheme.heroGreen
                                    : AppTheme.burntOrange,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.heroGreen
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _prettyType(m.type),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.heroGreen,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd MMM, HH:mm')
                                    .format(m.createdAt),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.onLightMuted),
                              ),
                              if (m.unitCostMinor != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '@ KSh ${(m.unitCostMinor! / 100).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.onLightMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<Map<String, String>> _loadProductNames(
      List<StockMovement> movements) async {
    final ids = movements.map((m) => m.productId).toSet();
    final names = <String, String>{};
    for (final id in ids) {
      final p = await widget.provider.db.getProductName(id);
      if (p != null) names[id] = p;
    }
    return names;
  }

  String _prettyType(String type) {
    switch (type) {
      case 'opening_stock':
        return 'Opening';
      case 'purchase':
        return 'Purchase';
      case 'sale':
        return 'Sale';
      case 'adjustment':
        return 'Adjustment';
      case 'return':
        return 'Return';
      case 'damage':
        return 'Damage';
      default:
        return type;
    }
  }
}