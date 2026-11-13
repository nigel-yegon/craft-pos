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
import '../../core/widgets/motion.dart';

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

    final salesQuery = db.select(db.sales)
      ..where((s) => s.businessId.equals(widget.businessId))
      ..where((s) => s.status.equals('completed'))
      ..where((s) => s.createdAt.isBiggerOrEqualValue(start))
      ..where((s) => s.createdAt.isSmallerThanValue(end));

    final sales = await salesQuery.get();
    final todaySales = sales.fold(0, (sum, s) => sum + s.totalAmountMinor);
    final todayTransactions = sales.length;

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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGradientBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _loadDashboardData,
            color: Colors.white,
            backgroundColor: AppTheme.primaryGreen,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Top bar ───
                  RevealOnMount(
                    delay: const Duration(milliseconds: 50),
                    child: _buildTopBar(context),
                  ),

                  const SizedBox(height: 20),

                  // ─── Hero metric cards (2×2 grid) ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RevealOnMount(
                                delay: const Duration(milliseconds: 150),
                                child: _buildHeroCard(
                                  label: 'Today\'s Sales',
                                  value: _todaySales,
                                  icon: Icons.trending_up,
                                  gradient: const [
                                    Color(0xFFFFB74D),
                                    Color(0xFFF57C00),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RevealOnMount(
                                delay: const Duration(milliseconds: 250),
                                child: _buildHeroCard(
                                  label: 'Today\'s Profit',
                                  value: _todayProfit,
                                  icon: Icons.attach_money,
                                  gradient: const [
                                    Color(0xFF66BB6A),
                                    Color(0xFF2E7D32),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: RevealOnMount(
                                delay: const Duration(milliseconds: 350),
                                child: _buildMiniMetric(
                                  label: 'Transactions',
                                  value: '$_todayTransactions',
                                  icon: Icons.receipt_long,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RevealOnMount(
                                delay: const Duration(milliseconds: 450),
                                child: _buildMiniMetric(
                                  label: 'Products Sold',
                                  value: '$_productsSold',
                                  icon: Icons.inventory_2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── Quick actions ───
                  RevealOnMount(
                    delay: const Duration(milliseconds: 550),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildQuickAction(
                            icon: Icons.shopping_cart,
                            label: 'New Sale',
                            onTap: () => context.go('/sales'),
                          ),
                          _buildQuickAction(
                            icon: Icons.inventory,
                            label: 'Stock',
                            onTap: () => context.go('/inventory'),
                          ),
                          _buildQuickAction(
                            icon: Icons.add_box,
                            label: 'Add Product',
                            onTap: () => context.go('/products'),
                          ),
                          _buildQuickAction(
                            icon: Icons.bar_chart,
                            label: 'Reports',
                            onTap: () => context.go('/reports'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── Low stock alert ───
                  if (_lowStockCount > 0)
                    RevealOnMount(
                      delay: const Duration(milliseconds: 650),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: PressableCard(
                          color: Colors.orange.shade50,
                          onTap: () => context.go('/inventory'),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$_lowStockCount product(s) low on stock',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const Text(
                                      'Tap to view inventory',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.orange),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top bar ───
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: StreamBuilder<BusinessesData?>(
                stream: widget.businessProvider.businessStream,
                builder: (context, snapshot) {
                  final biz = snapshot.data;
                  final imagePath = biz?.imagePath;
                  final hasImage =
                      imagePath != null && File(imagePath).existsSync();

                  return Row(
                    children: [
                      Hero(
                        tag: 'shop-avatar',
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 2,
                            ),
                            image: hasImage
                                ? DecorationImage(
                              image: FileImage(File(imagePath)),
                              fit: BoxFit.cover,
                            )
                                : null,
                            color: hasImage ? null : Colors.white24,
                          ),
                          child: !hasImage
                              ? const Icon(Icons.store,
                              color: Colors.white, size: 24)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              biz?.name ?? 'My Shop',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Hi, ${widget.authProvider.currentUser?.name ?? 'Owner'}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings, color: Colors.white),
            tooltip: 'Settings',
          ),
          IconButton(
            onPressed: () {
              widget.authProvider.logout();
              context.go('/login');
            },
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  // ─── Hero metric card ───
  Widget _buildHeroCard({
    required String label,
    required int value,
    required IconData icon,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 16),
          AnimatedCounter(
            value: value ~/ 100, // display as KSh whole number
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
            formatter: (v) => 'KSh $v',
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Mini metric ───
  Widget _buildMiniMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.9), size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.75),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Quick action ───
  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}