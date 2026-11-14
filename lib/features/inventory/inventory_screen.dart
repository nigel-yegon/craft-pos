// lib/features/inventory/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/app_database.dart';
import '../../core/providers/product_provider.dart';
import '../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════
// INVENTORY LIST SCREEN — routed at /inventory
// ═══════════════════════════════════════════════════════════════════

class InventoryScreen extends StatefulWidget {
  final ProductProvider provider;
  const InventoryScreen({super.key, required this.provider});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _search = '';

  // ⭐ Filter state
  String _stockStatus = 'all'; // 'all' | 'in' | 'low' | 'out'
  String _sortBy = 'name_asc';

  bool get _hasActiveFilters =>
      _stockStatus != 'all' || _sortBy != 'name_asc';

  void _clearFilters() {
    setState(() {
      _stockStatus = 'all';
      _sortBy = 'name_asc';
    });
  }

  String _filterDescription() {
    final parts = <String>[];
    if (_stockStatus != 'all') {
      parts.add(switch (_stockStatus) {
        'in' => 'In stock',
        'low' => 'Low stock',
        'out' => 'Out of stock',
        _ => _stockStatus,
      });
    }
    if (_sortBy != 'name_asc') {
      parts.add(switch (_sortBy) {
        'name_desc' => 'Name Z→A',
        'stock_high' => 'Stock high→low',
        'stock_low' => 'Stock low→high',
        'recent' => 'Recently updated',
        _ => _sortBy,
      });
    }
    return parts.isEmpty ? 'All products' : parts.join(' • ');
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
                      const Text('Filter Stock',
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
                  const Text('Stock Status',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildStatusChip('All', 'all', setModalState),
                      _buildStatusChip('In stock', 'in', setModalState),
                      _buildStatusChip('Low stock', 'low', setModalState),
                      _buildStatusChip('Out of stock', 'out', setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Sort by',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildSortChip('Name A→Z', 'name_asc', setModalState),
                      _buildSortChip('Name Z→A', 'name_desc', setModalState),
                      _buildSortChip('Stock high→low', 'stock_high', setModalState),
                      _buildSortChip('Stock low→high', 'stock_low', setModalState),
                      _buildSortChip('Recently updated', 'recent', setModalState),
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

  Widget _buildStatusChip(
      String label, String value, StateSetter setModalState) {
    final selected = _stockStatus == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setModalState(() => _stockStatus = value);
        setState(() {});
      },
      selectedColor: AppTheme.heroGreen.withValues(alpha: 0.1),
      checkmarkColor: AppTheme.heroGreen,
      labelStyle: TextStyle(
        color: selected ? AppTheme.heroGreen : AppTheme.inkBlack,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _buildSortChip(
      String label, String value, StateSetter setModalState) {
    final selected = _sortBy == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setModalState(() => _sortBy = value);
        setState(() {});
      },
      selectedColor: AppTheme.heroGreen.withValues(alpha: 0.1),
      checkmarkColor: AppTheme.heroGreen,
      labelStyle: TextStyle(
        color: selected ? AppTheme.heroGreen : AppTheme.inkBlack,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Stock'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ⭐ Search + filter button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search products by name or SKU...',
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
                      color: _hasActiveFilters
                          ? AppTheme.heroGreen.withValues(alpha: 0.1)
                          : AppTheme.softMint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.tune,
                      color: _hasActiveFilters
                          ? AppTheme.heroGreen
                          : AppTheme.heroGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ⭐ Active filter summary bar
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

          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: widget.provider.productsStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!.where((p) {
                  return p.name.toLowerCase().contains(_search) ||
                      (p.sku?.toLowerCase().contains(_search) ?? false);
                }).toList();

                if (all.isEmpty) {
                  return const Center(
                    child: Text(
                      'No products found.',
                      style: TextStyle(color: AppTheme.textLight),
                    ),
                  );
                }

                // ⭐ Apply filters + sort
                return _buildFilteredList(all);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.navClearance),
        child: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AdjustStockScreen(provider: widget.provider),
            ),
          ),
          backgroundColor: AppTheme.brightGreen,
          foregroundColor: AppTheme.inkBlack,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildFilteredList(List<Product> products) {
    // For status filtering and stock sorting, we need the stock per product.
    // Fetch stocks in parallel, then apply filters/sorts.
    return FutureBuilder<List<_StockEntry>>(
      future: Future.wait(
        products.map((p) async {
          final stockMilli =
          await widget.provider.db.getProductStock(p.id);
          return _StockEntry(product: p, stockMilli: stockMilli);
        }),
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var entries = snapshot.data!;

        // Status filter
        entries = entries.where((e) {
          switch (_stockStatus) {
            case 'in':
              return e.stockMilli > e.product.reorderLevelMilli;
            case 'low':
              return e.stockMilli > 0 &&
                  e.stockMilli <= e.product.reorderLevelMilli;
            case 'out':
              return e.stockMilli <= 0;
            default:
              return true;
          }
        }).toList();

        // Sort
        switch (_sortBy) {
          case 'name_asc':
            entries.sort((a, b) =>
                a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()));
            break;
          case 'name_desc':
            entries.sort((a, b) =>
                b.product.name.toLowerCase().compareTo(a.product.name.toLowerCase()));
            break;
          case 'stock_high':
            entries.sort((a, b) => b.stockMilli.compareTo(a.stockMilli));
            break;
          case 'stock_low':
            entries.sort((a, b) => a.stockMilli.compareTo(b.stockMilli));
            break;
          case 'recent':
            entries.sort((a, b) =>
                b.product.updatedAt.compareTo(a.product.updatedAt));
            break;
        }

        if (entries.isEmpty) {
          return const Center(
            child: Text(
              'No products match your filters.',
              style: TextStyle(color: AppTheme.textLight),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            AppTheme.navClearance + 24,
          ),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return _InventoryRow(
              product: entry.product,
              stockMilli: entry.stockMilli,
              provider: widget.provider,
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STOCK ENTRY — bundles product + precomputed stock for filtering
// ═══════════════════════════════════════════════════════════════════

class _StockEntry {
  final Product product;
  final int stockMilli;
  const _StockEntry({required this.product, required this.stockMilli});
}

// ═══════════════════════════════════════════════════════════════════
// EXPANDABLE INVENTORY ROW
// ═══════════════════════════════════════════════════════════════════

class _InventoryRow extends StatelessWidget {
  final Product product;
  final int stockMilli;
  final ProductProvider provider;

  const _InventoryRow({
    required this.product,
    required this.stockMilli,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final stock = stockMilli / 1000.0;
    final isLow = stockMilli > 0 && stockMilli <= product.reorderLevelMilli;
    final isOut = stockMilli <= 0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text(
            product.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  isOut
                      ? Icons.remove_circle_outline
                      : isLow
                      ? Icons.warning_amber_rounded
                      : Icons.inventory_2_outlined,
                  size: 14,
                  color: isOut
                      ? AppTheme.textMuted
                      : isLow
                      ? AppTheme.warningRed
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Stock: ${stock.toStringAsFixed(2)} ${product.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOut
                        ? AppTheme.textMuted
                        : isLow
                        ? AppTheme.warningRed
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isLow) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.warningRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LOW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.warningRed,
                      ),
                    ),
                  ),
                ],
                if (isOut) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.textMuted.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'OUT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 12),
            _detailRow(
              'Selling price',
              'KSh ${(product.sellingPriceMinor / 100).toStringAsFixed(2)}',
            ),
            _detailRow(
              'Cost price',
              'KSh ${(product.costPriceMinor / 100).toStringAsFixed(2)}',
            ),
            _detailRow(
              'Reorder at',
              '${(product.reorderLevelMilli / 1000).toStringAsFixed(2)} ${product.unit}',
            ),
            const SizedBox(height: 12),
            Divider(
                color: AppTheme.inkBlack.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 12),
            _LastMovementPanel(product: product, provider: provider),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdjustStockScreen(
                      provider: provider,
                      initialProduct: product,
                    ),
                  ),
                ),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Adjust stock'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.heroGreen,
                  side: BorderSide(
                      color: AppTheme.heroGreen.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// LAST MOVEMENT PANEL
// ═══════════════════════════════════════════════════════════════════

class _LastMovementPanel extends StatelessWidget {
  final Product product;
  final ProductProvider provider;

  const _LastMovementPanel({
    required this.product,
    required this.provider,
  });

  Future<StockMovement?> _fetch() async {
    return await (provider.db.select(provider.db.stockMovements)
      ..where((m) => m.productId.equals(product.id))
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
      ..limit(1))
        .getSingleOrNull();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StockMovement?>(
      future: _fetch(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 40,
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final m = snapshot.data;
        if (m == null) {
          return const Text(
            'No stock movements yet.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.onLightMuted,
              fontStyle: FontStyle.italic,
            ),
          );
        }

        final isIn = m.quantityMilli > 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last movement',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  isIn ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 14,
                  color: isIn
                      ? AppTheme.primaryGreen
                      : AppTheme.burntOrange,
                ),
                const SizedBox(width: 6),
                Text(
                  '${isIn ? '+' : ''}'
                      '${(m.quantityMilli / 1000).toStringAsFixed(2)} '
                      '${product.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isIn
                        ? AppTheme.primaryGreen
                        : AppTheme.burntOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.heroGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _prettyType(m.type),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.heroGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM yyyy, HH:mm').format(m.createdAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.onLightMuted,
              ),
            ),
            if (m.note != null && m.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                m.note!,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.onLightMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        );
      },
    );
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

// ═══════════════════════════════════════════════════════════════════
// ADJUST STOCK SCREEN
// ═══════════════════════════════════════════════════════════════════

class AdjustStockScreen extends StatefulWidget {
  final ProductProvider provider;
  final Product? initialProduct;

  const AdjustStockScreen({
    super.key,
    required this.provider,
    this.initialProduct,
  });

  @override
  State<AdjustStockScreen> createState() => _AdjustStockScreenState();
}

class _AdjustStockScreenState extends State<AdjustStockScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();
  final _unitCostController = TextEditingController();

  Product? _selectedProduct;
  String _direction = 'add';
  String _reason = 'adjustment';
  String _search = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    _unitCostController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product first')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final quantity = double.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) return;

    final deltaMilli =
        (_direction == 'add' ? 1 : -1) * (quantity * 1000).round();

    int? unitCostMinor;
    if (_direction == 'add') {
      final parsed = double.tryParse(_unitCostController.text);
      if (parsed != null && parsed >= 0) {
        unitCostMinor = (parsed * 100).toInt();
      }
    }

    setState(() => _saving = true);

    try {
      await widget.provider.adjustStock(
        productId: _selectedProduct!.id,
        deltaMilli: deltaMilli,
        reason: _reason,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        unitCostMinor: unitCostMinor,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to adjust stock: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Adjust Stock'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.inkBlack),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: _saving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.check, color: AppTheme.inkBlack),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectedProduct == null) ...[
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Search product',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) =>
                    setState(() => _search = v.toLowerCase()),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.inkBlack.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: StreamBuilder<List<Product>>(
                    stream: widget.provider.productsStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      final matches = snapshot.data!.where((p) {
                        return p.name
                            .toLowerCase()
                            .contains(_search) ||
                            (p.sku
                                ?.toLowerCase()
                                .contains(_search) ??
                                false);
                      }).toList();

                      if (matches.isEmpty) {
                        return const Center(
                          child: Text('No products match.'),
                        );
                      }

                      return ListView.separated(
                        itemCount: matches.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: AppTheme.inkBlack.withValues(alpha: 0.06),
                        ),
                        itemBuilder: (_, index) {
                          final p = matches[index];
                          return ListTile(
                            leading: const Icon(
                                Icons.inventory_2_outlined,
                                color: AppTheme.heroGreen),
                            title: Text(
                              p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500),
                            ),
                            subtitle: p.sku != null
                                ? Text('SKU: ${p.sku}')
                                : null,
                            onTap: () => setState(() {
                              _selectedProduct = p;
                              _search = '';
                            }),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.softMint,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.heroGreen
                                .withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.inventory_2_outlined,
                                color: AppTheme.heroGreen),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedProduct!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      color: AppTheme.inkBlack,
                                    ),
                                  ),
                                  Text(
                                    'Current price: KSh ${(_selectedProduct!.sellingPriceMinor / 100).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.onLightMuted),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                  Icons.change_circle_outlined,
                                  color: AppTheme.inkBlack),
                              tooltip: 'Change product',
                              onPressed: () => setState(
                                      () => _selectedProduct = null),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Add Stock'),
                              selected: _direction == 'add',
                              selectedColor: AppTheme.heroGreen,
                              labelStyle: TextStyle(
                                color: _direction == 'add'
                                    ? Colors.white
                                    : AppTheme.inkBlack,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) =>
                                  setState(() => _direction = 'add'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Remove Stock'),
                              selected: _direction == 'remove',
                              selectedColor: AppTheme.burntOrange,
                              labelStyle: TextStyle(
                                color: _direction == 'remove'
                                    ? Colors.white
                                    : AppTheme.inkBlack,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) =>
                                  setState(() => _direction = 'remove'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _quantityController,
                        keyboardType:
                        const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          labelText: _direction == 'add'
                              ? 'Quantity to add'
                              : 'Quantity to remove',
                          suffixText: 'units',
                          prefixIcon: const Icon(Icons.numbers),
                        ),
                        validator: (v) {
                          final qty = double.tryParse(v ?? '');
                          if (qty == null || qty <= 0) {
                            return 'Enter a positive quantity';
                          }
                          return null;
                        },
                      ),

                      if (_direction == 'add') ...[
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _unitCostController,
                          keyboardType:
                          const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Unit cost for this batch (KSh)',
                            hintText: 'e.g. 45.50',
                            prefixIcon:
                            const Icon(Icons.attach_money),
                            helperText:
                            _selectedProduct?.costPriceMinor != null
                                ? 'Current cost: KSh ${(_selectedProduct!.costPriceMinor / 100).toStringAsFixed(2)}'
                                : null,
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return null;
                            final n = double.tryParse(v);
                            if (n == null || n < 0) {
                              return 'Enter a valid cost';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 20),

                      DropdownButtonFormField<String>(
                        initialValue: _reason,
                        decoration: const InputDecoration(
                          labelText: 'Reason',
                          prefixIcon: Icon(Icons.report),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'purchase',
                            child: Text(_direction == 'add'
                                ? 'Purchase / restock'
                                : 'Return to supplier'),
                          ),
                          DropdownMenuItem(
                            value: 'adjustment',
                            child: Text(_direction == 'add'
                                ? 'Stock count (found extra)'
                                : 'Stock count (found less)'),
                          ),
                          DropdownMenuItem(
                            value: 'damage',
                            child: Text(_direction == 'add'
                                ? 'Recovered from damage'
                                : 'Damaged / expired'),
                          ),
                          DropdownMenuItem(
                            value: 'return',
                            child: Text(_direction == 'add'
                                ? 'Customer return'
                                : 'Return to supplier'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _reason = v);
                        },
                      ),
                      const SizedBox(height: 20),

                      TextFormField(
                        controller: _noteController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Note (optional)',
                          hintText: 'e.g., Received from supplier #123',
                          prefixIcon: Icon(Icons.notes),
                        ),
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.check),
                          label: Text(
                              _saving ? 'Saving...' : 'Apply Adjustment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.heroGreen,
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}