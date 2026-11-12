import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/product_provider.dart';
import '../../core/theme/app_theme.dart';
import '../products/product_form_screen.dart';
import 'adjust_stock_screen.dart';
import 'stock_report_screen.dart';

class InventoryScreen extends StatelessWidget {
  final ProductProvider provider;
  const InventoryScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory & Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment),
            tooltip: 'Stock Report',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StockReportScreen(provider: provider),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Product>>(
        stream: provider.productsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final products = snapshot.data!;
          if (products.isEmpty) {
            return const Center(child: Text('No products found.'));
          }

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final p = products[index];
              return FutureBuilder<int>(
                future: provider.db.getProductStock(p.id),
                builder: (context, stockSnapshot) {
                  final stockMilli = stockSnapshot.data ?? 0;
                  final stockDouble = stockMilli / 1000.0;
                  final isLow = stockMilli <= p.reorderLevelMilli;

                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      'Cost: KES ${(p.costPriceMinor / 100).toStringAsFixed(2)}',
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Stock: $stockDouble',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isLow ? AppTheme.warningRed : Colors.green,
                          ),
                        ),
                        if (isLow)
                          const Text(
                            'LOW STOCK',
                            style: TextStyle(
                                color: AppTheme.warningRed, fontSize: 10),
                          ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductFormScreen(
                          provider: provider,
                          product: p,
                        ),
                      ),
                    ),
                    onLongPress: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdjustStockScreen(
                            provider: provider,
                            initialProduct: p,
                          ),
                        ),
                      );
                      if (changed == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Stock adjusted'),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        );
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.tune),
        label: const Text('Adjust Stock'),
        onPressed: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => AdjustStockScreen(provider: provider),
            ),
          );
          if (changed == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Stock adjusted'),
                backgroundColor: AppTheme.primaryGreen,
              ),
            );
          }
        },
      ),
    );
  }
}