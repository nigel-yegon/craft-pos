import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // ⭐ added: context.pop / context.go
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/sales_provider.dart';
import '../../core/theme/app_theme.dart';

class HeldOrdersScreen extends StatefulWidget {
  final SalesProvider provider;
  const HeldOrdersScreen({super.key, required this.provider});

  @override
  State<HeldOrdersScreen> createState() => _HeldOrdersScreenState();
}

class _HeldOrdersScreenState extends State<HeldOrdersScreen> {
  final Map<String, List<CartItem>> _cartCache = {};

  Future<List<CartItem>> _loadCartItems(HeldOrder order) async {
    if (_cartCache.containsKey(order.id)) {
      return _cartCache[order.id]!;
    }
    final items = await widget.provider.loadHeldOrder(order);
    _cartCache[order.id] = items;
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Held Orders')),
      body: StreamBuilder<List<HeldOrder>>(
        stream: widget.provider.heldOrdersStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(
              child: Text('No held orders',
                  style: TextStyle(color: AppTheme.textLight)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = orders[index];
              return _buildHeldOrderTile(order);
            },
          );
        },
      ),
    );
  }

  Widget _buildHeldOrderTile(HeldOrder order) {
    final total = (order.totalAmountMinor / 100).toStringAsFixed(2);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.pause_circle,
              color: Colors.orange, size: 20),
        ),
        title: Text(
          'KSh $total',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${DateFormat('dd MMM, HH:mm').format(order.createdAt)}'
              '${order.note != null ? ' • ${order.note}' : ''}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Cancel order',
              onPressed: () => _confirmCancel(context, order),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow,
                  color: AppTheme.primaryGreen),
              tooltip: 'Resume',
              onPressed: () => _resume(context, order),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 8),
          FutureBuilder<List<CartItem>>(
            future: _loadCartItems(order),
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

              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('No items in this held order.'),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...items.map((item) {
                    final qty = item.quantityMilli / 1000.0;
                    final qtyLabel = qty % 1 == 0
                        ? qty.toStringAsFixed(0)
                        : qty.toStringAsFixed(2);
                    final lineTotal = item.lineTotalMinor / 100.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.product.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            '$qtyLabel × KSh ${(item.product.sellingPriceMinor / 100).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textLight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            child: Text(
                              'KSh ${lineTotal.toStringAsFixed(2)}',
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

  Future<void> _confirmCancel(
      BuildContext context, HeldOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Held Order?'),
        content: const Text('This will delete the held order.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _cartCache.remove(order.id);
      await widget.provider.deleteHeldOrder(order.id);
    }
  }

  // ⭐ Resume: load cart, delete the held order, then pop back with the cart.
  //    Uses go_router's context.pop so it works with the router-based
  //    navigation (/sales → held). No provider mutation is performed here,
  //    so SalesProvider doesn't need a restoreHeldOrder() method.
  Future<void> _resume(BuildContext context, HeldOrder order) async {
    final cart = await widget.provider.loadHeldOrder(order);
    if (!context.mounted) return;

    _cartCache.remove(order.id);
    await widget.provider.deleteHeldOrder(order.id);
    if (!context.mounted) return;

    // Pop back to the caller (usually /sales) with the cart as the result.
    if (context.canPop()) {
      context.pop(cart);
    } else {
      // Fallback: if this screen was opened as the root (e.g. deep link),
      // go to the sales screen. The cart will be empty there unless the
      // caller handles the pop result; add SalesProvider.restoreHeldOrder()
      // if you need the cart to survive this path.
      context.go('/sales');
    }
  }
}