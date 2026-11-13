import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart'; // ⭐ Import intl for formatting

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
  int _todayExpenses = 0;

  // ⭐ Localized Currency Formatter
  final _currencyFormatter = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'KSh ',
    decimalDigits: 2,
  );

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

    // 1. Sales
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
    final productsSold =
    ((stockResult?.read<int?>('total_sold') ?? 0) ~/ 1000);

    // 4. Expenses (Paid today)
    final expenseQuery = db.customSelect(
      '''
      SELECT SUM(paid_amount_minor) as total
      FROM expenses
      WHERE business_id = ? AND status = 'paid'
      AND created_at >= ? AND created_at < ?
      ''',
      variables: [
        Variable.withString(widget.businessId),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {db.expenses},
    );
    final expenseResult = await expenseQuery.getSingleOrNull();
    final todayExpenses = expenseResult?.read<int?>('total') ?? 0;

    // 5. Low stock
    final lowStock = await db.getLowStockCount(widget.businessId);

    if (!mounted) return;
    setState(() {
      _todaySales = todaySales;
      _todayProfit = todayProfit;
      _todayTransactions = todayTransactions;
      _productsSold = productsSold;
      _todayExpenses = todayExpenses;
      _lowStockCount = lowStock;
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadDashboardData,
          color: AppTheme.brightGreen,
          backgroundColor: AppTheme.heroGreen,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              0,
              0,
              0,
              MediaQuery.of(context).padding.bottom + 100,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ═══ HERO CARD ═══
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.midGreen,
                        AppTheme.heroGreen,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.heroGreen.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: Hero(
                              tag: 'shop-avatar',
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 0.5,
                                  ),
                                ),
                                child: StreamBuilder<BusinessesData?>(
                                  stream: widget.businessProvider.businessStream,
                                  builder: (context, snapshot) {
                                    final imagePath = snapshot.data?.imagePath;
                                    if (imagePath != null && File(imagePath).existsSync()) {
                                      return ClipOval(
                                        child: Image.file(
                                          File(imagePath),
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        ),
                                      );
                                    }
                                    return const Icon(Icons.person,
                                        color: Colors.white, size: 20);
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                StreamBuilder<BusinessesData?>(
                                  stream: widget.businessProvider.businessStream,
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data?.name ?? 'My Shop',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          _heroIconButton(
                            icon: Icons.search,
                            onTap: () => _openUniversalSearch(context),
                          ),
                          const SizedBox(width: 8),
                          _heroIconButton(
                            icon: Icons.notifications_none_outlined,
                            onTap: () {},
                          ),
                        ],
                      ),

                      const SizedBox(height: 26),

                      Text(
                        'Total balance',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'KSh ',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _currencyFormatter.format(_todaySales / 100).replaceFirst('KSh ', ''),
                            style: const TextStyle(
                              fontSize: 34,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.2,
                              height: 1,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      Row(
                        children: [
                          _heroPill(
                            label: 'Stock Summary',
                            icon: Icons.analytics_outlined,
                            isPrimary: false,
                            onTap: () => context.push('/reports/stock'),
                          ),
                          const SizedBox(width: 10),
                          _heroPill(
                            label: 'Held Orders',
                            icon: Icons.pause_circle_outline,
                            isPrimary: true,
                            onTap: () => context.push('/sales/held'),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => context.push('/settings'),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 0.5,
                                ),
                              ),
                              child: const Icon(Icons.more_horiz,
                                  color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ═══ WHITE PANEL (Quick Links) ═══
                Transform.translate(
                  offset: const Offset(0, -12),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.heroGreen.withValues(alpha: 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quick Links',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.inkBlack,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.9,
                          children: [
                            _categoryItem(
                              icon: Icons.shopping_cart_outlined,
                              label: 'Sale',
                              onTap: () => context.go('/sales'),
                            ),
                            _categoryItem(
                              icon: Icons.inventory_2_outlined,
                              label: 'Stock',
                              onTap: () => context.go('/inventory'),
                            ),
                            _categoryItem(
                              icon: Icons.storefront_outlined,
                              label: 'Products',
                              onTap: () => context.go('/products'),
                            ),
                            _categoryItem(
                              icon: Icons.bar_chart_rounded,
                              label: 'Reports',
                              onTap: () => context.go('/reports'),
                            ),
                            _categoryItem(
                              icon: Icons.receipt_long_outlined,
                              label: 'Transactions',
                              onTap: () => context.go('/reports'),
                            ),
                            _categoryItem(
                              icon: Icons.attach_money_outlined,
                              label: 'Profit',
                              onTap: () => context.go('/reports'),
                            ),
                            _categoryItem(
                              icon: Icons.payments_outlined,
                              label: 'Expenses',
                              onTap: () => context.push('/settings'),
                            ),
                            _categoryItem(
                              icon: Icons.settings_outlined,
                              label: 'Settings',
                              onTap: () => context.push('/settings'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // ═══ METRICS GRID ═══
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.inkBlack,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Today\'s total activity',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.onLightMuted,
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: _metricCard(
                              title: 'Today\'s Sales',
                              value: _currencyFormatter.format(_todaySales / 100),
                              icon: Icons.shopping_bag_outlined,
                              bgColor: AppTheme.heroGreen,
                              onTap: () => context.go('/sales'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricCard(
                              title: 'Today\'s Profit',
                              value: _currencyFormatter.format(_todayProfit / 100),
                              icon: Icons.trending_up,
                              bgColor: AppTheme.midGreen,
                              onTap: () => context.go('/reports'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _metricCard(
                              title: 'Transactions',
                              value: '$_todayTransactions',
                              icon: Icons.receipt_long_outlined,
                              bgColor: AppTheme.forestDeep,
                              onTap: () => context.go('/reports'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _metricCard(
                              title: 'Expenses',
                              value: _currencyFormatter.format(_todayExpenses / 100),
                              icon: Icons.payments_outlined,
                              bgColor: AppTheme.midnightViolet,
                              onTap: () => context.push('/settings'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ═══ LOW STOCK ═══
                if (_lowStockCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: GestureDetector(
                      onTap: () => context.go('/inventory'),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.burntOrange.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppTheme.burntOrange.withValues(alpha: 0.35),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppTheme.burntOrange, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '$_lowStockCount product(s) low on stock',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.inkBlack,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: AppTheme.burntOrange.withValues(alpha: 0.7),
                                size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUniversalSearch(BuildContext context) async {
    await showSearch(
      context: context,
      delegate: _UniversalSearchDelegate(
        db: ref.read(databaseProvider),
        businessId: widget.businessId,
      ),
    );
  }

  Widget _heroIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }

  Widget _heroPill({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.brightGreen,
              Color(0xFF2BB673),
            ],
          )
              : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.03),
            ],
          ),
          borderRadius: BorderRadius.circular(999),
          border: isPrimary
              ? null
              : Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isPrimary ? AppTheme.inkBlack : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isPrimary ? AppTheme.inkBlack : Colors.white,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.softMint,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.heroGreen.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: AppTheme.heroGreen, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.inkBlack,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon,
                    size: 18, color: Colors.white.withValues(alpha: 0.6)),
                Icon(Icons.arrow_outward,
                    size: 14, color: Colors.white.withValues(alpha: 0.3)),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.8,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// UNIVERSAL SEARCH
// ═══════════════════════════════════════════════════════════════════

class _UniversalSearchDelegate extends SearchDelegate {
  final AppDatabase db;
  final String businessId;

  _UniversalSearchDelegate({required this.db, required this.businessId});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.inkBlack),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: AppTheme.inkBlack.withValues(alpha: 0.4),
          fontSize: 16,
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: AppTheme.inkBlack, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.close, color: AppTheme.inkBlack),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: AppTheme.inkBlack),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return _emptyState(
        icon: Icons.search,
        title: 'Search everything',
        subtitle:
        'Find products, transactions, expenses, or held orders.',
      );
    }
    return FutureBuilder<List<_SearchResult>>(
      future: _search(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.burntOrange),
          );
        }
        final results = snapshot.data!;
        if (results.isEmpty) {
          return _emptyState(
            icon: Icons.search_off,
            title: 'No results',
            subtitle: 'Nothing matches "$query"',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final r = results[index];
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.inkBlack.withValues(alpha: 0.06),
                  width: 0.5,
                ),
              ),
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.burntOrange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(r.icon,
                      color: AppTheme.burntOrange, size: 16),
                ),
                title: Text(
                  r.title,
                  style: const TextStyle(
                    color: AppTheme.inkBlack,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  r.subtitle,
                  style: TextStyle(
                    color: AppTheme.inkBlack.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
                trailing: Icon(Icons.chevron_right,
                    color: AppTheme.inkBlack.withValues(alpha: 0.3), size: 18),
                onTap: () {
                  close(context, null);
                  r.onTap(context);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 48,
                color: AppTheme.inkBlack.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.inkBlack,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.inkBlack.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<_SearchResult>> _search(String q) async {
    final term = q.toLowerCase();
    final results = <_SearchResult>[];

    final products = await (db.select(db.products)
      ..where((p) => p.businessId.equals(businessId)))
        .get();

    for (final p in products) {
      if (p.name.toLowerCase().contains(term) ||
          (p.sku?.toLowerCase().contains(term) ?? false) ||
          (p.barcode?.toLowerCase().contains(term) ?? false)) {
        results.add(_SearchResult(
          icon: Icons.inventory_2_outlined,
          title: p.name,
          subtitle:
          'Product · KSh ${(p.sellingPriceMinor / 100).toStringAsFixed(2)}',
          onTap: (ctx) => ctx.go('/products'),
        ));
      }
    }

    final categories = await (db.select(db.categories)
      ..where((c) => c.businessId.equals(businessId)))
        .get();

    for (final c in categories) {
      if (c.name.toLowerCase().contains(term)) {
        results.add(_SearchResult(
          icon: Icons.category_outlined,
          title: c.name,
          subtitle: 'Category',
          onTap: (ctx) => ctx.go('/products'),
        ));
      }
    }

    final sales = await (db.select(db.sales)
      ..where((s) => s.businessId.equals(businessId))
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
      ..limit(50))
        .get();

    for (final s in sales) {
      final amount =
          'KSh ${(s.totalAmountMinor / 100).toStringAsFixed(2)}';
      if (amount.toLowerCase().contains(term) ||
          s.paymentMethod?.toLowerCase().contains(term) == true) {
        results.add(_SearchResult(
          icon: Icons.receipt_long_outlined,
          title: amount,
          subtitle:
          '${s.paymentMethod ?? 'Sale'} · ${_formatDate(s.createdAt)}',
          onTap: (ctx) => ctx.go('/reports'),
        ));
      }
    }

    final expenses = await (db.select(db.expenses)
      ..where((e) => e.businessId.equals(businessId))
      ..limit(50))
        .get();

    for (final e in expenses) {
      if (e.name.toLowerCase().contains(term) ||
          e.category.toLowerCase().contains(term)) {
        results.add(_SearchResult(
          icon: Icons.payments_outlined,
          title: e.name,
          subtitle:
          '${e.category} · KSh ${(e.amountMinor / 100).toStringAsFixed(2)}',
          onTap: (ctx) => ctx.go('/settings'),
        ));
      }
    }

    final held = await (db.select(db.heldOrders)
      ..where((h) => h.businessId.equals(businessId))
      ..limit(20))
        .get();

    for (final h in held) {
      if ((h.note?.toLowerCase().contains(term) ?? false) ||
          'held'.contains(term)) {
        results.add(_SearchResult(
          icon: Icons.pause_circle_outline,
          title: 'Held order',
          subtitle:
          'KSh ${(h.totalAmountMinor / 100).toStringAsFixed(2)} · ${h.note ?? ''}',
          onTap: (ctx) => ctx.go('/sales'),
        ));
      }
    }

    return results;
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _SearchResult {
  final IconData icon;
  final String title;
  final String subtitle;
  final void Function(BuildContext) onTap;

  _SearchResult({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}