import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _isNavVisible = true;
  double _lastScrollOffset = 0;

  static const _tabs = [
    ('/dashboard', Icons.home_outlined, Icons.home, 'Home'),
    ('/products', Icons.storefront_outlined, Icons.storefront, 'Products'),
    ('/sales', Icons.shopping_cart_outlined, Icons.shopping_cart, 'Sales'),
    ('/inventory', Icons.inventory_2_outlined, Icons.inventory_2, 'Stock'),
    ('/reports', Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
  ];

  int _indexForLocation(String location) {
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final currentOffset = notification.metrics.pixels;

      if (currentOffset > _lastScrollOffset && currentOffset > 50) {
        if (_isNavVisible) setState(() => _isNavVisible = false);
      } else if (currentOffset < _lastScrollOffset) {
        if (!_isNavVisible) setState(() => _isNavVisible = true);
      }

      _lastScrollOffset = currentOffset;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _indexForLocation(location);

    return Scaffold(
      backgroundColor: Colors.white,
      // ⭐ Body extends behind the pill so content scrolls *under* it.
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey(location),
            child: widget.child,
          ),
        ),
      ),
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: _isNavVisible ? Offset.zero : const Offset(0, 1.5),
        child: _buildFloatingNav(currentIndex),
      ),
    );
  }

  Widget _buildFloatingNav(int currentIndex) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomGap = bottomInset > 0 ? bottomInset + 4 : 18.0;

    return Container(
      // ⭐ Soft green gradient strip behind the pill — hides the white
      //    scaffold body that would otherwise bleed through the pill's
      //    shadow while content scrolls behind it.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppTheme.heroGreen.withValues(alpha: 0.15),
            AppTheme.heroGreen.withValues(alpha: 0.35),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomGap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.heroGreen,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppTheme.heroGreen.withValues(alpha: 0.32),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final selected = i == currentIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => context.go(_tabs[i].$1),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.brightGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? _tabs[i].$3 : _tabs[i].$2,
                        size: 24,
                        color: selected
                            ? AppTheme.inkBlack
                            : Colors.white.withValues(alpha: 0.9),
                      ),
                      if (selected) ...[
                        const SizedBox(height: 2),
                        Text(
                          _tabs[i].$4,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.inkBlack,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}