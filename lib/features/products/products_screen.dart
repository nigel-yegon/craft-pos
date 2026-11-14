import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search products by name or SKU...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (val) =>
                  setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
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

                final allProducts = snapshot.data ?? [];
                final filteredProducts = allProducts.where((p) {
                  return p.name.toLowerCase().contains(_searchQuery) ||
                      (p.sku?.toLowerCase().contains(_searchQuery) ?? false);
                }).toList();

                if (filteredProducts.isEmpty) {
                  return const Center(
                    child: Text(
                      'No products found.',
                      style: TextStyle(color: AppTheme.textLight),
                    ),
                  );
                }

                return ListView.separated(
                  // ⭐ Bottom padding so the last row isn't hidden behind
                  //    the pill when the content scrolls under it.
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
      // ⭐ FAB pushed above the pill via the shared clearance constant.
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.navClearance + 24),
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