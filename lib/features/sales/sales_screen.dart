import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/product_provider.dart';
import '../../core/providers/sales_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/product_image.dart';
import 'held_orders_screen.dart';

class SalesScreen extends StatefulWidget {
  final ProductProvider productProvider;
  final SalesProvider salesProvider;

  const SalesScreen({
    super.key,
    required this.productProvider,
    required this.salesProvider,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final List<CartItem> _cart = [];
  String _searchQuery = '';
  bool _cartExpanded = true;

  int get _cartTotalMinor => _cart.fold(
    0,
        (sum, item) =>
    sum + (item.product.sellingPriceMinor * item.quantityMilli ~/ 1000),
  );

  int get _cartItemCount =>
      _cart.fold(0, (sum, item) => sum + (item.quantityMilli ~/ 1000));

  void _addToCart(Product product) {
    setState(() {
      final existing = _cart.indexWhere((i) => i.product.id == product.id);
      if (existing >= 0) {
        _cart[existing].quantityMilli += 1000;
      } else {
        _cart.add(CartItem(product: product));
      }
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      if (_cart[index].quantityMilli > 1000) {
        _cart[index].quantityMilli -= 1000;
      } else {
        _cart.removeAt(index);
      }
    });
  }

  // ─── Pay now ──────────────────────────────────────────────────────
  Future<void> _payNow() async {
    if (_cart.isEmpty) return;

    final total = _cartTotalMinor;
    final method = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose Payment Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
              const Icon(Icons.money, color: AppTheme.primaryGreen),
              title: const Text('Cash'),
              subtitle: Text('KSh ${(total / 100).toStringAsFixed(2)}'),
              onTap: () => Navigator.pop(ctx, 'Cash'),
            ),
            ListTile(
              leading:
              const Icon(Icons.phone_android, color: Colors.green),
              title: const Text('M-Pesa'),
              subtitle: Text('KSh ${(total / 100).toStringAsFixed(2)}'),
              onTap: () => Navigator.pop(ctx, 'M-Pesa'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.grey),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx, null),
            ),
          ],
        ),
      ),
    );

    if (method == null) return;

    await widget.salesProvider.completeSale(
      cart: _cart,
      totalAmountMinor: total,
      paymentMethod: method,
    );

    if (!mounted) return;
    setState(() {
      _cart.clear();
      _cartExpanded = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sale complete — $method'),
        backgroundColor: AppTheme.primaryGreen,
      ),
    );
  }

  // ─── Hold order ───────────────────────────────────────────────────
  Future<void> _holdOrder() async {
    if (_cart.isEmpty) return;

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hold Order'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            hintText: 'e.g., Customer will pay later',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hold'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.salesProvider.holdOrder(
      cart: _cart,
      totalAmountMinor: _cartTotalMinor,
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _cart.clear();
      _cartExpanded = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Order held — open Held Orders to resume')),
    );
  }

  // ─── Open Held Orders ────────────────────────────────────────────
  Future<void> _openHeldOrders() async {
    final result = await Navigator.push<List<CartItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => HeldOrdersScreen(provider: widget.salesProvider),
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        _cart.clear();
        _cart.addAll(result);
        _cartExpanded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.pending_actions),
            tooltip: 'Held Orders',
            onPressed: _openHeldOrders,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (_cartExpanded && _cart.isNotEmpty) {
                  setState(() => _cartExpanded = false);
                }
              },
              behavior: HitTestBehavior.deferToChild,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search products by name or SKU...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.toLowerCase()),
                    ),
                  ),
                  Expanded(
                    child: isWideScreen
                        ? Row(
                      children: [
                        Expanded(
                            flex: 3, child: _buildProductGrid()),
                        if (_cartExpanded)
                          Expanded(
                              flex: 2, child: _buildCart()),
                      ],
                    )
                        : Column(
                      children: [
                        Expanded(
                            flex: 3, child: _buildProductGrid()),
                        if (_cartExpanded)
                          SizedBox(
                              height: 350, child: _buildCart()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ⭐ Floating cart pill — ALWAYS visible when collapsed
          if (!_cartExpanded)
            Positioned(
              bottom: 20,
              right: 20,
              child: _buildFloatingCartBadge(),
            ),
        ],
      ),
    );
  }

  // ─── Floating cart pill (always visible when collapsed) ──────────
  Widget _buildFloatingCartBadge() {
    final isEmpty = _cart.isEmpty;

    return GestureDetector(
      onTap: () => setState(() => _cartExpanded = true),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(30),
        color: isEmpty
            ? Colors.grey.shade700
            : AppTheme.primaryGreen,
        child: Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: isEmpty
                  ? [Colors.grey.shade700, Colors.grey.shade600]
                  : [
                AppTheme.primaryGreen,
                AppTheme.primaryGreen.withValues(alpha: 0.85),
              ],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart,
                      color: Colors.white, size: 26),
                  if (!isEmpty)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '$_cartItemCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isEmpty ? 'Cart is empty' : 'View Cart',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isEmpty
                        ? 'Tap to open'
                        : 'KSh ${(_cartTotalMinor / 100).toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    return StreamBuilder<List<Product>>(
      stream: widget.productProvider.productsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final prods = snapshot.data!.where((p) {
          return p.name.toLowerCase().contains(_searchQuery) ||
              (p.sku?.toLowerCase().contains(_searchQuery) ?? false);
        }).toList();

        if (prods.isEmpty) {
          return const Center(
            child: Text('No products found',
                style: TextStyle(color: AppTheme.textLight)),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            childAspectRatio: 0.85,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: prods.length,
          itemBuilder: (context, index) {
            final p = prods[index];
            return GestureDetector(
              onTap: () {
                _addToCart(p);
                if (!_cartExpanded) {
                  setState(() => _cartExpanded = true);
                }
              },
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        height: 60,
                        width: double.infinity,
                        child: ProductImage(
                          imagePath: p.imagePath,
                          size: 60,
                          borderRadius: 8,
                        ),
                      ),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'KSh ${(p.sellingPriceMinor / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCart() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Current Order',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _cartExpanded = false),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_cart.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.grey),
                    onPressed: () => setState(() => _cart.clear()),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _cart.isEmpty
                ? const Center(
              child: Text('Cart is empty',
                  style: TextStyle(color: Colors.grey)),
            )
                : ListView.builder(
              itemCount: _cart.length,
              itemBuilder: (context, index) {
                final item = _cart[index];
                return ListTile(
                  title: Text(item.product.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500)),
                  subtitle: Text(
                      'KSh ${(item.product.sellingPriceMinor / 100).toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                            Icons.remove_circle_outline,
                            size: 20),
                        onPressed: () => _removeFromCart(index),
                      ),
                      Text('${item.quantityMilli ~/ 1000}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      IconButton(
                        icon: const Icon(
                            Icons.add_circle_outline,
                            size: 20,
                            color: AppTheme.primaryGreen),
                        onPressed: () => _addToCart(item.product),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.textLight)),
                    Text(
                      'KSh ${(_cartTotalMinor / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _cart.isEmpty ? null : _holdOrder,
                        icon: const Icon(Icons.pause_circle_outline),
                        label: const Text('Hold'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _cart.isEmpty ? null : _payNow,
                        icon: const Icon(Icons.check),
                        label: const Text('Pay'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}