import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/product_provider.dart';
import '../../core/theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Report'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryGreen,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textLight,
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

  // ═══ Summary tab ═══
  Widget _buildSummaryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.provider.getStockSummary(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;

        if (rows.isEmpty) {
          return const Center(child: Text('No products yet.'));
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _totalsItem('Stock In',
                          '${(grandIn / 1000).toStringAsFixed(0)}'),
                      _totalsItem('Stock Out',
                          '${(grandOut / 1000).toStringAsFixed(0)}'),
                      _totalsItem('Balance',
                          '${(grandBalance / 1000).toStringAsFixed(0)}'),
                      _totalsItem(
                          'Value', 'KSh ${grandValue.toStringAsFixed(0)}'),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final p = row['product'] as Product;
                  final totalIn = row['totalIn'] as int;
                  final totalOut = row['totalOut'] as int;
                  final balance = row['balance'] as int;
                  final valueMinor = row['valueMinor'] as int;
                  final avgCostMinor = row['avgCostMinor'] as int;
                  final isLow = row['isLow'] as bool;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              '${(balance / 1000).toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isLow
                                    ? AppTheme.warningRed
                                    : AppTheme.textDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _smallChip(
                                '+${(totalIn / 1000).toStringAsFixed(0)}',
                                Colors.green),
                            const SizedBox(width: 6),
                            _smallChip(
                                '-${(totalOut / 1000).toStringAsFixed(0)}',
                                Colors.red),
                            const SizedBox(width: 8),
                            if (isLow)
                              const Text(
                                'LOW STOCK',
                                style: TextStyle(
                                  color: AppTheme.warningRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const Spacer(),
                            Flexible(
                              child: Text(
                                'Avg: KSh ${(avgCostMinor / 100).toStringAsFixed(2)} • '
                                    'Value: KSh ${(valueMinor / 100).toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textLight),
                                overflow: TextOverflow.ellipsis,
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
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textLight)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppTheme.textDark)),
      ],
    );
  }

  Widget _smallChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ═══ Ledger tab ═══
  Widget _buildLedgerTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search by product, note, or type...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
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
                      style: TextStyle(color: AppTheme.textLight)),
                );
              }

              return FutureBuilder<Map<String, String>>(
                future: _loadProductNames(movements),
                builder: (context, nameSnapshot) {
                  final names = nameSnapshot.data ?? {};

                  final filtered = movements.where((m) {
                    final name =
                    (names[m.productId] ?? '').toLowerCase();
                    final note = (m.note ?? '').toLowerCase();
                    final type = m.type.toLowerCase();
                    return name.contains(_search) ||
                        note.contains(_search) ||
                        type.contains(_search);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No movements match your search.',
                          style: TextStyle(color: AppTheme.textLight)),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final m = filtered[index];
                      final isIn = m.quantityMilli > 0;
                      final productName =
                          names[m.productId] ?? '(deleted)';
                      final qty = (m.quantityMilli / 1000).toStringAsFixed(
                          m.quantityMilli % 1000 == 0 ? 0 : 2);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: (isIn ? Colors.green : Colors.red)
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isIn
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isIn ? Colors.green : Colors.red,
                            size: 18,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ),
                            Text(
                              '${isIn ? '+' : ''}$qty',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIn
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
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
                                  color: AppTheme.primaryGreen
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _prettyType(m.type),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.primaryGreen,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('dd MMM, HH:mm')
                                    .format(m.createdAt),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textLight),
                              ),
                              if (m.unitCostMinor != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '@ KSh ${(m.unitCostMinor! / 100).toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textLight),
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