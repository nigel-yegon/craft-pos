import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;

import '../../core/database/app_database.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/business_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/theme/app_theme.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final String businessId;
  final AuthProvider authProvider;
  final BusinessProvider businessProvider;

  const DashboardScreen({
    super.key,
    required this.businessId,
    required this.authProvider,
    required this.businessProvider,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _todaySales = 0;
  int _todayProfit = 0;
  int _todayTransactions = 0;
  int _productsSold = 0;
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    final db = ref.read(databaseProvider);

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    // 1. Today's Sales
    final salesQuery = db.select(db.sales)
      ..where((s) => s.businessId.equals(widget.businessId))
      ..where((s) => s.status.equals('completed'))
      ..where((s) => s.createdAt.isBiggerOrEqualValue(start))
      ..where((s) => s.createdAt.isSmallerThanValue(end));

    final sales = await salesQuery.get();
    final todaySales = sales.fold(0, (sum, s) => sum + s.totalAmountMinor);
    final todayTransactions = sales.length;

    // 2. Profit
    final profitQuery = db.customSelect(
      '''
      SELECT SUM((si.unit_price_minor - si.cost_price_minor) * (si.quantity_milli / 1000.0)) as profit
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.business_id = ? AND s.status = 'completed'
      AND s.created_at >= ? AND s.created_at < ?
      ''',
      variables: [
        Variable.withString(widget.businessId),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {db.sales, db.saleItems},
    );
    final profitResult = await profitQuery.getSingleOrNull();
    final todayProfit = (profitResult?.read<double?>('profit') ?? 0).round();

    // 3. Products Sold
    final stockQuery = db.customSelect(
      '''
      SELECT SUM(ABS(quantity_milli)) as total_sold
      FROM stock_movements
      WHERE business_id = ? AND type = 'sale'
      AND created_at >= ? AND created_at < ?
      ''',
      variables: [
        Variable.withString(widget.businessId),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {db.stockMovements},
    );
    final stockResult = await stockQuery.getSingleOrNull();
    final productsSold = ((stockResult?.read<int?>('total_sold') ?? 0) ~/ 1000);

    // 4. Low stock
    final lowStock = await db.getLowStockCount(widget.businessId);

    if (!mounted) return;
    setState(() {
      _todaySales = todaySales;
      _todayProfit = todayProfit;
      _todayTransactions = todayTransactions;
      _productsSold = productsSold;
      _lowStockCount = lowStock;
    });
  }

  String _formatKsh(int minorUnits) =>
      'KSh ${(minorUnits / 100).toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── Green Header ───
            Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/profile'),
                        child: StreamBuilder<BusinessesData?>(
                          stream: widget.businessProvider.businessStream,
                          builder: (context, snapshot) {
                            final biz = snapshot.data;
                            final imagePath = biz?.imagePath;
                            final hasImage = imagePath != null &&
                                File(imagePath).existsSync();

                            return Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.white24,
                                  backgroundImage:
                                  hasImage ? FileImage(File(imagePath)) : null,
                                  child: !hasImage
                                      ? const Icon(Icons.store,
                                      color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      biz?.name ?? 'My Shop',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      widget.authProvider.currentUser?.name ??
                                          'Owner',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        tooltip: 'Logout',
                        onPressed: () {
                          widget.authProvider.logout();
                          context.go('/login');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildHeaderMetricCard(
                          'Today\'s Sales', _formatKsh(_todaySales)),
                      const SizedBox(width: 12),
                      _buildHeaderMetricCard(
                          'Today\'s Profit', _formatKsh(_todayProfit)),
                    ],
                  ),
                ],
              ),
            ),

            // ─── Quick Actions ───
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickAction(Icons.shopping_cart, 'New Sale',
                      onTap: () => context.go('/sales')),
                  _buildQuickAction(Icons.inventory, 'Stock',
                      onTap: () => context.go('/inventory')),
                  _buildQuickAction(Icons.add_box, 'Add Product',
                      onTap: () => context.go('/products')),
                  _buildQuickAction(Icons.bar_chart, 'Reports',
                      onTap: () => context.go('/reports')),
                ],
              ),
            ),

            // ─── Low Stock Alert ───
            if (_lowStockCount > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.warningRed.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppTheme.warningRed),
                      const SizedBox(width: 12),
                      Text(
                        '$_lowStockCount product(s) running low on stock',
                        style: const TextStyle(
                          color: AppTheme.warningRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ─── Today's Activity ───
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Today\'s Activity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTransactionMetric(
                            Icons.receipt_long,
                            '$_todayTransactions',
                            'Transactions',
                            Colors.green,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey.shade300,
                          ),
                          _buildTransactionMetric(
                            Icons.inventory_2,
                            '$_productsSold',
                            'Products Sold',
                            Colors.orange,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderMetricCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label,
      {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTransactionMetric(
      IconData icon, String value, String label, Color iconColor) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.1),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                style:
                const TextStyle(fontSize: 10, color: AppTheme.textLight)),
          ],
        ),
      ],
    );
  }
}