import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/product_provider.dart';
import '../../core/providers/sales_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/product_image.dart';

class SalesScreen extends StatefulWidget {
  final ProductProvider productProvider;
  final SalesProvider salesProvider;

  /// ⭐ When true, the held-orders screen opens immediately after mount.
  /// Used by the dashboard "Held Orders" shortcut so the resume cart
  /// always has a live SalesScreen to pop back into.
  final bool autoOpenHeldOrders;

  const SalesScreen({
    super.key,
    required this.productProvider,
    required this.salesProvider,
    this.autoOpenHeldOrders = false,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final List<CartItem> _cart = [];
  String _searchQuery = '';
  bool _cartExpanded = false;

  int get _cartTotalMinor => _cart.fold(
    0,
        (sum, item) =>
    sum + (item.product.sellingPriceMinor * item.quantityMilli ~/ 1000),
  );

  int get _cartItemCount =>
      _cart.fold(0, (sum, item) => sum + (item.quantityMilli ~/ 1000));

  @override
  void initState() {
    super.initState();
    if (widget.autoOpenHeldOrders) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openHeldOrders();
      });
    }
  }

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

  Future<void> _payNow() async {
    if (_cart.isEmpty) return;

    final total = _cartTotalMinor;

    final result = await showDialog<_PaymentResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SplitPaymentDialog(totalMinor: total),
    );

    if (result == null || !mounted) return;

    // Cap recorded amounts at the sale total so overpayment (change) isn't
    // double-counted in sale_payments.
    int remaining = total;
    final splits = <SalePaymentSplit>[];

    if (result.cashMinor > 0) {
      final cashRecorded =
      result.cashMinor >= remaining ? remaining : result.cashMinor;
      splits.add(SalePaymentSplit('cash', cashRecorded));
      remaining -= cashRecorded;
    }
    if (remaining > 0 && result.mpesaMinor > 0) {
      splits.add(SalePaymentSplit(
        'mpesa',
        remaining,
        reference: result.mpesaReference,
      ));
      remaining = 0;
    }

    final methodLabel =
    splits.length > 1 ? 'cash+mpesa' : splits.first.method;

    await widget.salesProvider.completeSale(
      cart: _cart,
      totalAmountMinor: total,
      paymentMethod: methodLabel,
      payments: splits,
    );

    if (!mounted) return;
    setState(() {
      _cart.clear();
      _cartExpanded = false;
    });

    final message = result.changeMinor > 0
        ? 'Sale complete — change: KSh '
        '${(result.changeMinor / 100).toStringAsFixed(2)}'
        : 'Sale complete — $methodLabel';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _holdOrder() async {
    if (_cart.isEmpty) return;

    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hold order',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Customer will pay later',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Hold'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
      SnackBar(
        content: const Text('Order held — open Held Orders to resume'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _openHeldOrders() async {
    final restored = await context.push<List<CartItem>>('/sales/held');

    if (!mounted) return;

    if (restored != null && restored.isNotEmpty) {
      setState(() {
        _cart
          ..clear()
          ..addAll(restored);
        _cartExpanded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('New Sale'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
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
                      Expanded(flex: 3, child: _buildProductGrid()),
                      if (_cartExpanded)
                        Expanded(flex: 2, child: _buildCart()),
                    ],
                  )
                      : Column(
                    children: [
                      Expanded(flex: 3, child: _buildProductGrid()),
                      if (_cartExpanded)
                        SizedBox(height: 380, child: _buildCart()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ⭐ Floating cart badge — clears the nav pill.
          if (!_cartExpanded)
            Positioned(
              bottom: AppTheme.navClearance + 20,
              right: 20,
              child: _buildFloatingCartBadge(),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingCartBadge() {
    final isEmpty = _cart.isEmpty;

    return GestureDetector(
      onTap: () => setState(() => _cartExpanded = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isEmpty ? AppTheme.textMuted : AppTheme.deepForest,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppTheme.deepForest.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart,
                    color: Colors.white, size: 24),
                if (!isEmpty)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppTheme.warningRed,
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
                  isEmpty ? 'Cart is empty' : 'View cart',
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
                style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        return GridView.builder(
          // ⭐ Bottom padding so the last row of products isn't hidden
          //    behind the nav pill when scrolled to the end.
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            AppTheme.navClearance + 24,
          ),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190,
            childAspectRatio: 0.82,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: prods.length,
          itemBuilder: (context, index) {
            final p = prods[index];
            return GestureDetector(
              onTap: () => _addToCart(p),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.deepForest.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SizedBox(
                        height: 80,
                        width: double.infinity,
                        child: ProductImage(
                          imagePath: p.imagePath,
                          size: 80,
                          borderRadius: 14,
                        ),
                      ),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'KSh ${(p.sellingPriceMinor / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.deepForest.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Current order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => _cartExpanded = false),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_cart.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppTheme.textMuted),
                    onPressed: () => setState(() => _cart.clear()),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.surfaceMuted),
          Expanded(
            child: _cart.isEmpty
                ? const Center(
              child: Text('Your cart is empty',
                  style: TextStyle(
                      color: AppTheme.textMuted, fontSize: 13)),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _cart.length,
              itemBuilder: (context, index) {
                final item = _cart[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color:
                      AppTheme.surfaceMuted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'KSh ${(item.product.sellingPriceMinor / 100).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                    Icons.remove_rounded,
                                    size: 18),
                                color: AppTheme.textPrimary,
                                onPressed: () =>
                                    _removeFromCart(index),
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4),
                                child: Text(
                                  '${item.quantityMilli ~/ 1000}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_rounded,
                                    size: 18),
                                color: AppTheme.primaryGreen,
                                onPressed: () =>
                                    _addToCart(item.product),
                                constraints: const BoxConstraints(
                                    minWidth: 32, minHeight: 32),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppTheme.surfaceMuted),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    Text(
                      'KSh ${(_cartTotalMinor / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _cart.isEmpty ? null : _holdOrder,
                        icon: const Icon(Icons.pause_circle_outline,
                            size: 18),
                        label: const Text('Hold'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: const BorderSide(
                              color: AppTheme.surfaceMuted),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _cart.isEmpty ? null : _payNow,
                        icon: const Icon(Icons.check, size: 18),
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

// ═══════════════════════════════════════════════════════════════════
// SPLIT PAYMENT DIALOG
// ═══════════════════════════════════════════════════════════════════

class _PaymentResult {
  final int cashMinor;
  final int mpesaMinor;
  final int changeMinor;
  final String? mpesaReference;

  const _PaymentResult({
    required this.cashMinor,
    required this.mpesaMinor,
    required this.changeMinor,
    this.mpesaReference,
  });
}

class _SplitPaymentDialog extends StatefulWidget {
  final int totalMinor;
  const _SplitPaymentDialog({required this.totalMinor});

  @override
  State<_SplitPaymentDialog> createState() => _SplitPaymentDialogState();
}

class _SplitPaymentDialogState extends State<_SplitPaymentDialog> {
  final _cashController = TextEditingController();
  final _mpesaController = TextEditingController();
  final _referenceController = TextEditingController();
  String? _error;

  int _parseKsh(String input) {
    final cleaned = input.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return 0;
    final v = double.tryParse(cleaned);
    if (v == null || v < 0) return 0;
    return (v * 100).round();
  }

  int get _cashMinor => _parseKsh(_cashController.text);
  int get _mpesaMinor => _parseKsh(_mpesaController.text);
  int get _paidMinor => _cashMinor + _mpesaMinor;
  int get _balanceMinor => widget.totalMinor - _paidMinor;
  int get _changeMinor => _balanceMinor < 0 ? -_balanceMinor : 0;
  bool get _canSubmit => _paidMinor >= widget.totalMinor;

  @override
  void dispose() {
    _cashController.dispose();
    _mpesaController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _fillRemainingCash() {
    final remaining = widget.totalMinor - _mpesaMinor;
    if (remaining > 0) {
      _cashController.text = (remaining / 100).toStringAsFixed(2);
      setState(() => _error = null);
    }
  }

  void _fillRemainingMpesa() {
    final remaining = widget.totalMinor - _cashMinor;
    if (remaining > 0) {
      _mpesaController.text = (remaining / 100).toStringAsFixed(2);
      setState(() => _error = null);
    }
  }

  void _submit() {
    if (!_canSubmit) {
      setState(() => _error = 'Paid amount must be at least KSh '
          '${(widget.totalMinor / 100).toStringAsFixed(2)}');
      return;
    }
    Navigator.pop(
      context,
      _PaymentResult(
        cashMinor: _cashMinor,
        mpesaMinor: _mpesaMinor,
        changeMinor: _changeMinor,
        mpesaReference: _referenceController.text.trim().isEmpty
            ? null
            : _referenceController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final overpaid = _balanceMinor < 0;
    final exact = _balanceMinor == 0 && _paidMinor > 0;

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Split Payment',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'Enter amounts paid. Change is calculated automatically.',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary)),
                    Text(
                      'KSh ${(widget.totalMinor / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cashController,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Cash',
                        prefixText: 'KSh ',
                        prefixIcon: Icon(Icons.money),
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Fill remaining',
                    onPressed: _fillRemainingCash,
                    icon: const Icon(Icons.auto_fix_high, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mpesaController,
                      keyboardType:
                      const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'M-Pesa',
                        prefixText: 'KSh ',
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                      onChanged: (_) => setState(() => _error = null),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Fill remaining',
                    onPressed: _fillRemainingMpesa,
                    icon: const Icon(Icons.auto_fix_high, size: 20),
                  ),
                ],
              ),
              if (_mpesaMinor > 0) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'M-Pesa receipt (optional)',
                    prefixIcon:
                    Icon(Icons.confirmation_number_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: overpaid
                      ? AppTheme.heroGreen.withValues(alpha: 0.08)
                      : exact
                      ? AppTheme.softMint
                      : AppTheme.burntOrange
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      overpaid
                          ? 'Change due'
                          : exact
                          ? 'Fully paid'
                          : 'Balance due',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: overpaid || exact
                            ? AppTheme.heroGreen
                            : AppTheme.burntOrange,
                      ),
                    ),
                    Text(
                      'KSh ${((overpaid ? _changeMinor : _balanceMinor.abs()) / 100).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: overpaid || exact
                            ? AppTheme.heroGreen
                            : AppTheme.burntOrange,
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.burntOrange)),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brightGreen,
                        foregroundColor: AppTheme.inkBlack,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999)),
                      ),
                      child: const Text('Complete',
                          style:
                          TextStyle(fontWeight: FontWeight.w700)),
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
}