import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/app_database.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/product_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/product_image.dart';
import '../categories/categories_screen.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  final ProductProvider provider;
  final CategoryProvider categoryProvider;

  const ProductsScreen({
    super.key,
    required this.provider,
    required this.categoryProvider,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _searchQuery = '';

  // ⭐ Filter state
  String? _filterCategoryId;
  String _filterPrice = 'all';
  String _filterActive = 'all'; // 'all' | 'active' | 'inactive'
  String _sortBy = 'name_asc';

  List<Category> _categories = const [];

  bool get _hasActiveFilters =>
      _filterCategoryId != null ||
          _filterPrice != 'all' ||
          _filterActive != 'all' ||
          _sortBy != 'name_asc';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final list = await widget.categoryProvider.categoriesStream.first;
    if (!mounted) return;
    setState(() => _categories = list);
  }

  void _clearFilters() {
    setState(() {
      _filterCategoryId = null;
      _filterPrice = 'all';
      _filterActive = 'all';
      _sortBy = 'name_asc';
    });
  }

  String _filterDescription() {
    final parts = <String>[];
    if (_filterCategoryId != null) {
      final cat = _categories.where((c) => c.id == _filterCategoryId);
      if (cat.isNotEmpty) parts.add(cat.first.name);
    }
    if (_filterPrice != 'all') {
      parts.add(switch (_filterPrice) {
        'under50' => '< KSh 50',
        '50_100' => 'KSh 50–100',
        '100_200' => 'KSh 100–200',
        'over200' => '> KSh 200',
        _ => _filterPrice,
      });
    }
    if (_filterActive != 'all') {
      parts.add(_filterActive == 'active' ? 'Active' : 'Inactive');
    }
    if (_sortBy != 'name_asc') {
      parts.add(switch (_sortBy) {
        'name_desc' => 'Name Z→A',
        'price_low' => 'Price low→high',
        'price_high' => 'Price high→low',
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
                      const Text('Filter Products',
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

                  // Category
                  if (_categories.isNotEmpty) ...[
                    const Text('Category',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildCategoryChip('All', null, setModalState),
                        ..._categories.map((c) =>
                            _buildCategoryChip(c.name, c.id, setModalState)),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Status
                  const Text('Status',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildStatusChip('All', 'all', setModalState),
                      _buildStatusChip('Active', 'active', setModalState),
                      _buildStatusChip('Inactive', 'inactive', setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Price
                  const Text('Price range',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildPriceChip('All', 'all', setModalState),
                      _buildPriceChip('< KSh 50', 'under50', setModalState),
                      _buildPriceChip('KSh 50–100', '50_100', setModalState),
                      _buildPriceChip('KSh 100–200', '100_200', setModalState),
                      _buildPriceChip('> KSh 200', 'over200', setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Sort
                  const Text('Sort by',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildSortChip('Name A→Z', 'name_asc', setModalState),
                      _buildSortChip('Name Z→A', 'name_desc', setModalState),
                      _buildSortChip('Price low→high', 'price_low', setModalState),
                      _buildSortChip('Price high→low', 'price_high', setModalState),
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

  Widget _buildCategoryChip(
      String label, String? value, StateSetter setModalState) {
    final selected = _filterCategoryId == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setModalState(() => _filterCategoryId = value);
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

  Widget _buildStatusChip(
      String label, String value, StateSetter setModalState) {
    final selected = _filterActive == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setModalState(() => _filterActive = value);
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

  Widget _buildPriceChip(
      String label, String value, StateSetter setModalState) {
    final selected = _filterPrice == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setModalState(() => _filterPrice = value);
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

  List<Product> _applyFilters(List<Product> products) {
    var filtered = products.where((p) {
      final matchesSearch = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery) ||
          (p.sku?.toLowerCase().contains(_searchQuery) ?? false);
      if (!matchesSearch) return false;

      if (_filterCategoryId != null && p.categoryId != _filterCategoryId) {
        return false;
      }

      if (_filterActive != 'all') {
        final wanted = _filterActive == 'active';
        if (p.isActive != wanted) return false;
      }

      final priceMinor = p.sellingPriceMinor;
      switch (_filterPrice) {
        case 'under50':
          return priceMinor < 5000;
        case '50_100':
          return priceMinor >= 5000 && priceMinor < 10000;
        case '100_200':
          return priceMinor >= 10000 && priceMinor < 20000;
        case 'over200':
          return priceMinor >= 20000;
        default:
          return true;
      }
    }).toList();

    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'name_asc':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'name_desc':
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case 'price_low':
          return a.sellingPriceMinor.compareTo(b.sellingPriceMinor);
        case 'price_high':
          return b.sellingPriceMinor.compareTo(a.sellingPriceMinor);
        default:
          return 0;
      }
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CategoriesScreen(provider: widget.categoryProvider),
                ),
              );
            },
          ),
        ],
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
                        setState(() => _searchQuery = v.toLowerCase()),
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
                    child: const Icon(
                      Icons.tune,
                      color: AppTheme.heroGreen,
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

          const SizedBox(height: 4),

          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: widget.provider.productsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final filteredProducts = _applyFilters(snapshot.data ?? []);

                if (filteredProducts.isEmpty) {
                  return Center(
                    child: Text(
                      _hasActiveFilters
                          ? 'No products match your filters.'
                          : 'No products found.',
                      style: const TextStyle(color: AppTheme.textLight),
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
                  itemCount: filteredProducts.length,
                  separatorBuilder: (context, index) =>
                  const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = filteredProducts[index];
                    return FutureBuilder<int>(
                      future: widget.provider.db.getProductStock(p.id),
                      builder: (context, stockSnapshot) {
                        final stockMilli = stockSnapshot.data ?? 0;
                        final stockDouble = stockMilli / 1000.0;
                        final isLow = stockMilli <= p.reorderLevelMilli;

                        return Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: ProductImage(
                              imagePath: p.imagePath,
                              size: 50,
                            ),
                            title: Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textDark,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'KSh ${(p.sellingPriceMinor / 100).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppTheme.primaryGreen,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Stock: $stockDouble',
                                  style: TextStyle(
                                    color: isLow
                                        ? AppTheme.warningRed
                                        : AppTheme.textDark,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                if (isLow)
                                  const Text(
                                    'LOW STOCK',
                                    style: TextStyle(
                                      color: AppTheme.warningRed,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductFormScreen(
                                  provider: widget.provider,
                                  product: p,
                                ),
                              ),
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
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.navClearance),
        child: FloatingActionButton(
          child: const Icon(Icons.add),
          backgroundColor: AppTheme.brightGreen,
          foregroundColor: AppTheme.inkBlack,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductFormScreen(provider: widget.provider),
            ),
          ),
        ),
      ),
    );
  }
}