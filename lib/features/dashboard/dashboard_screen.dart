import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/business_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/notifications_provider.dart';
import '../../core/providers/subscription_provider.dart';
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
  int _lowStockCount = 0;
  int _todayExpenses = 0;

  String _ownerName = '';
  int _brandingSlideIndex = 0;

  List<Sale> _recentSales = const [];
  final Map<String, List<RecentSaleLine>> _recentLineCache = {};

  final _currencyFormatter = NumberFormat.currency(
    locale: 'en_KE',
    symbol: 'KSh ',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _loadOwnerName();
    _syncNotifications();
    _loadRecentSales();
  }

  Future<void> _syncNotifications() async {
    try {
      await ref.read(notificationsSyncProvider)();
    } catch (e) {
      debugPrint('Notifications sync failed: $e');
    }
  }

  Future<void> _loadOwnerName() async {
    final loggedIn = widget.authProvider.currentUser;
    if (loggedIn != null && loggedIn.name.trim().isNotEmpty) {
      if (mounted) setState(() => _ownerName = loggedIn.name.trim());
      return;
    }

    final db = ref.read(databaseProvider);
    final owner = await (db.select(db.users)
      ..where((u) => u.businessId.equals(widget.businessId))
      ..where((u) => u.role.equals('owner'))
      ..where((u) => u.isActive.equals(true))
      ..limit(1))
        .getSingleOrNull();

    if (owner != null && owner.name.trim().isNotEmpty && mounted) {
      setState(() => _ownerName = owner.name.trim());
    }
  }

  Future<void> _loadRecentSales() async {
    final db = ref.read(databaseProvider);
    final rows = await (db.select(db.sales)
      ..where((s) => s.businessId.equals(widget.businessId))
      ..where((s) => s.status.equals('completed'))
      ..orderBy([(s) => OrderingTerm.desc(s.createdAt)])
      ..limit(3))
        .get();
    if (!mounted) return;
    setState(() => _recentSales = rows);
  }

  Future<List<RecentSaleLine>> _loadRecentSaleLines(Sale sale) async {
    if (_recentLineCache.containsKey(sale.id)) {
      return _recentLineCache[sale.id]!;
    }
    final db = ref.read(databaseProvider);
    final items = await (db.select(db.saleItems)
      ..where((i) => i.saleId.equals(sale.id)))
        .get();

    final lines = <RecentSaleLine>[];
    for (final item in items) {
      final p = await (db.select(db.products)
        ..where((prod) => prod.id.equals(item.productId)))
          .getSingleOrNull();
      lines.add(RecentSaleLine(
        productName: p?.name ?? '(deleted product)',
        quantityMilli: item.quantityMilli,
        unitPriceMinor: item.unitPriceMinor,
        lineTotalMinor: item.lineTotalMinor,
      ));
    }
    _recentLineCache[sale.id] = lines;
    return lines;
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

    final lowStock = await db.getLowStockCount(widget.businessId);

    if (!mounted) return;
    setState(() {
      _todaySales = todaySales;
      _todayProfit = todayProfit;
      _todayTransactions = todayTransactions;
      _todayExpenses = todayExpenses;
      _lowStockCount = lowStock;
    });

    _syncNotifications();
    _loadRecentSales();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _prettyMethod(String m) {
    switch (m) {
      case 'cash': return 'Cash';
      case 'mpesa': return 'M-Pesa';
      case 'cash+mpesa': return 'Cash + M-Pesa';
      default: return m;
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to access your shop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    widget.authProvider.logout();
    if (!context.mounted) return;
    context.go('/login');
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
            padding: EdgeInsets.only(bottom: AppTheme.navClearance),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                // ═══ UPGRADE TO PRO BANNER (Now at bottom) ═══
                Consumer(
                  builder: (context, ref, _) {
                    final isTrialAsync = ref.watch(isTrialProvider);
                    return isTrialAsync.maybeWhen(
                      data: (isTrial) {
                        if (!isTrial) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: () => context.push('/settings/subscription'),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              // Deep green gradient to feel premium
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppTheme.forestDeep,
                                  AppTheme.heroGreen,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.forestDeep.withValues(alpha: 0.2),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Gold star icon
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.workspace_premium,
                                    color: Colors.amber,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Upgrade to Pro',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Unlock unlimited reports, cloud sync, and more.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white70,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // CTA Arrow
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    );
                  },
                ),
                // ═══ HERO CARD ═══
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.midGreen, AppTheme.heroGreen],
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
                                    return const Icon(Icons.person, color: Colors.white, size: 20);
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
                                StreamBuilder<BusinessesData?>(
                                  stream: widget.businessProvider.businessStream,
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data?.name ?? 'My Shop',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_greeting()}, ${_ownerName.isNotEmpty ? _ownerName : ''}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Consumer(
                            builder: (context, ref, _) {
                              final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;
                              return GestureDetector(
                                onTap: () => context.push('/settings/notifications'),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
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
                                      child: const Icon(Icons.notifications_none_outlined, size: 18, color: Colors.white),
                                    ),
                                    if (unread > 0)
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.brightGreen,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                          child: Text(
                                            unread > 99 ? '99+' : '$unread',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              height: 1,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _confirmLogout(context),
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
                              child: const Icon(Icons.logout, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
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
                            onTap: () => context.go('/sales', extra: {'openHeldOrders': true}),
                          ),
                          const SizedBox(width: 10),
                          _heroIconButton(
                            icon: Icons.search,
                            onTap: () => _openUniversalSearch(context),
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
                        LayoutBuilder(
                          builder: (context, constraints) {
                            const crossAxisSpacing = 10.0;
                            const mainAxisSpacing = 14.0;
                            const itemCount = 8;
                            final isWide = constraints.maxWidth >= 700;
                            final crossAxisCount = isWide ? 8 : 4;
                            final tileWidth = (constraints.maxWidth - crossAxisSpacing * (crossAxisCount - 1)) / crossAxisCount;

                            final items = <Widget>[
                              _categoryItem(icon: Icons.shopping_cart_outlined, label: 'Sale', isHighlighted: true, onTap: () => context.go('/sales')),
                              _categoryItem(icon: Icons.inventory_2_outlined, label: 'Stock', onTap: () => context.go('/inventory')),
                              _categoryItem(icon: Icons.storefront_outlined, label: 'Products', onTap: () => context.go('/products')),
                              _categoryItem(icon: Icons.bar_chart_rounded, label: 'Reports', onTap: () => context.go('/reports')),
                              _categoryItem(icon: Icons.receipt_long_outlined, label: 'Transactions', onTap: () => context.go('/reports')),
                              _categoryItem(icon: Icons.attach_money_outlined, label: 'Profit', onTap: () => context.go('/reports')),
                              _categoryItem(icon: Icons.payments_outlined, label: 'Expenses', onTap: () => context.push('/settings')),
                              _categoryItem(icon: Icons.settings_outlined, label: 'Settings', onTap: () => context.push('/settings')),
                            ];

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: itemCount,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: crossAxisSpacing,
                                mainAxisSpacing: mainAxisSpacing,
                                mainAxisExtent: tileWidth + 24,
                              ),
                              itemBuilder: (context, index) => items[index],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                _buildBrandingSlider(),

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
                            const Icon(Icons.warning_amber_rounded, color: AppTheme.burntOrange, size: 18),
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
                            Icon(Icons.chevron_right, color: AppTheme.burntOrange.withValues(alpha: 0.7), size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),

                // ═══ RECENT TRANSACTIONS ═══
                if (_recentSales.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Recent Transactions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.inkBlack,
                                letterSpacing: -0.2,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/reports/transactions'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'View all',
                                style: TextStyle(
                                  color: AppTheme.heroGreen,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._recentSales.map(_buildRecentSaleTile),
                      ],
                    ),
                  ),


              ],
            ),
          ),
        ),
      ),
    );
  }

  // ⭐ Recent sale tile — expandable, lazy-loads line items.
  Widget _buildRecentSaleTile(Sale sale) {
    final isSplit = (sale.paymentMethod ?? '').contains('+');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.inkBlack.withValues(alpha: 0.08)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.softMint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt, color: AppTheme.heroGreen, size: 18),
          ),
          title: Text(
            DateFormat('dd MMM, HH:mm').format(sale.createdAt),
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppTheme.inkBlack,
            ),
          ),
          subtitle: Text(
            _prettyMethod(sale.paymentMethod ?? 'cash'),
            style: const TextStyle(fontSize: 11, color: AppTheme.onLightMuted),
          ),
          trailing: Text(
            _currencyFormatter.format(sale.totalAmountMinor / 100),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppTheme.inkBlack,
            ),
          ),
          children: [
            Divider(color: AppTheme.inkBlack.withValues(alpha: 0.06), height: 1),
            const SizedBox(height: 10),
            FutureBuilder<List<RecentSaleLine>>(
              future: _loadRecentSaleLines(sale),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(10),
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                final lines = snapshot.data!;
                if (lines.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No line items recorded.',
                      style: TextStyle(fontSize: 11, color: AppTheme.onLightMuted),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Items',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        color: AppTheme.onLightSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...lines.map((line) {
                      final qty = line.quantityMilli / 1000.0;
                      final qtyLabel = qty % 1 == 0 ? qty.toStringAsFixed(0) : qty.toStringAsFixed(2);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(line.productName, style: const TextStyle(fontSize: 12)),
                            ),
                            Text(
                              '$qtyLabel × ${_currencyFormatter.format(line.unitPriceMinor / 100)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.onLightMuted),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 80,
                              child: Text(
                                _currencyFormatter.format(line.lineTotalMinor / 100),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (isSplit) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Paid with',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: AppTheme.onLightSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FutureBuilder<List<SalePayment>>(
                        future: (() async {
                          final db = ref.read(databaseProvider);
                          return (db.select(db.salePayments)..where((p) => p.saleId.equals(sale.id))).get();
                        })(),
                        builder: (context, snap) {
                          if (!snap.hasData) return const SizedBox();
                          return Column(
                            children: snap.data!.map((p) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  children: [
                                    Icon(
                                      p.method == 'cash' ? Icons.money : Icons.phone_android,
                                      size: 12,
                                      color: AppTheme.heroGreen,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(_prettyMethod(p.method), style: const TextStyle(fontSize: 11)),
                                    ),
                                    if (p.reference != null)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Text(
                                          p.reference!,
                                          style: const TextStyle(fontSize: 10, color: AppTheme.onLightMuted),
                                        ),
                                      ),
                                    Text(
                                      _currencyFormatter.format(p.amountMinor / 100),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ⭐ Branding slider — full-width gradient card with 3 slides.
  Widget _buildBrandingSlider() {
    const slides = [
      (icon: Icons.insights_outlined, title: 'Track every shilling', subtitle: 'Live sales, profit, and stock value — no spreadsheets.'),
      (icon: Icons.storefront_outlined, title: 'Sell faster, anywhere', subtitle: 'Cash, M-Pesa, or split payments — one tap.'),
      (icon: Icons.shield_outlined, title: 'Built for Kenyan shops', subtitle: 'Offline-first. Data stays on your device.'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 4, 24, 0),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.forestDeep, AppTheme.heroGreen, AppTheme.brightGreen],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.forestDeep.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 96,
            child: PageView.builder(
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _brandingSlideIndex = i),
              itemBuilder: (context, i) {
                final s = slides[i];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(s.icon, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            s.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.75),
                              height: 1.35,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slides.length, (i) {
              final selected = i == _brandingSlideIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: selected ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Text(
            'Craft Business — ideas, integrated.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
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
            colors: [AppTheme.brightGreen, Color(0xFF2BB673)],
          )
              : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.03)],
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
            Icon(icon, size: 14, color: isPrimary ? AppTheme.inkBlack : Colors.white),
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
    bool isHighlighted = false,
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
              color: isHighlighted ? AppTheme.heroGreen : AppTheme.softMint,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.heroGreen.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: isHighlighted ? Colors.white : AppTheme.heroGreen,
              size: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isHighlighted ? AppTheme.heroGreen : AppTheme.inkBlack,
              fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
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
                Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.6)),
                Icon(Icons.arrow_outward, size: 14, color: Colors.white.withValues(alpha: 0.3)),
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
// RECENT SALE LINE MODEL
// ═══════════════════════════════════════════════════════════════════

class RecentSaleLine {
  final String productName;
  final int quantityMilli;
  final int unitPriceMinor;
  final int lineTotalMinor;

  const RecentSaleLine({
    required this.productName,
    required this.quantityMilli,
    required this.unitPriceMinor,
    required this.lineTotalMinor,
  });
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
        hintStyle: TextStyle(color: AppTheme.inkBlack.withValues(alpha: 0.4), fontSize: 16),
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
        subtitle: 'Find products, transactions, expenses, or held orders.',
      );
    }
    return FutureBuilder<List<_SearchResult>>(
      future: _search(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.burntOrange));
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
                  child: Icon(r.icon, color: AppTheme.burntOrange, size: 16),
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
                trailing: Icon(
                  Icons.chevron_right,
                  color: AppTheme.inkBlack.withValues(alpha: 0.3),
                  size: 18,
                ),
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
            Icon(icon, size: 48, color: AppTheme.inkBlack.withValues(alpha: 0.25)),
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

    final products = await (db.select(db.products)..where((p) => p.businessId.equals(businessId))).get();
    for (final p in products) {
      if (p.name.toLowerCase().contains(term) ||
          (p.sku?.toLowerCase().contains(term) ?? false) ||
          (p.barcode?.toLowerCase().contains(term) ?? false)) {
        results.add(_SearchResult(
          icon: Icons.inventory_2_outlined,
          title: p.name,
          subtitle: 'Product · KSh ${(p.sellingPriceMinor / 100).toStringAsFixed(2)}',
          onTap: (ctx) => ctx.go('/products'),
        ));
      }
    }

    final categories = await (db.select(db.categories)..where((c) => c.businessId.equals(businessId))).get();
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
      final amount = 'KSh ${(s.totalAmountMinor / 100).toStringAsFixed(2)}';
      if (amount.toLowerCase().contains(term) || s.paymentMethod?.toLowerCase().contains(term) == true) {
        results.add(_SearchResult(
          icon: Icons.receipt_long_outlined,
          title: amount,
          subtitle: '${s.paymentMethod ?? 'Sale'} · ${_formatDate(s.createdAt)}',
          onTap: (ctx) => ctx.go('/reports'),
        ));
      }
    }

    final expenses = await (db.select(db.expenses)
      ..where((e) => e.businessId.equals(businessId))
      ..limit(50))
        .get();
    for (final e in expenses) {
      if (e.name.toLowerCase().contains(term) || e.category.toLowerCase().contains(term)) {
        results.add(_SearchResult(
          icon: Icons.payments_outlined,
          title: e.name,
          subtitle: '${e.category} · KSh ${(e.amountMinor / 100).toStringAsFixed(2)}',
          onTap: (ctx) => ctx.go('/settings'),
        ));
      }
    }

    final held = await (db.select(db.heldOrders)
      ..where((h) => h.businessId.equals(businessId))
      ..limit(20))
        .get();
    for (final h in held) {
      if ((h.note?.toLowerCase().contains(term) ?? false) || 'held'.contains(term)) {
        results.add(_SearchResult(
          icon: Icons.pause_circle_outline,
          title: 'Held order',
          subtitle: 'KSh ${(h.totalAmountMinor / 100).toStringAsFixed(2)} · ${h.note ?? ''}',
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