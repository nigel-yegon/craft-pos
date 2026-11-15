// lib/shared/widgets/app_shell.dart

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

  // Height reserved inside the body for the floating pill. Anything that
  // reads `MediaQuery.padding.bottom` inside a screen (FABs, SafeArea,
  // `bottom:` offsets) will clear the pill automatically.
  static const double _navReservedHeight = 100.0;

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
        // Scrolling down → hide.
        if (_isNavVisible) setState(() => _isNavVisible = false);
      } else if (currentOffset < _lastScrollOffset) {
        // Scrolling up → show.
        if (!_isNavVisible) setState(() => _isNavVisible = true);
      }

      _lastScrollOffset = currentOffset;
    }
    return false;
  }

  // ⭐ Tap anywhere on the content → reveal the nav if hidden.
  //    Listener with `translucent` fires for every pointer down, even
  //    when a child consumes the tap (button, tile, etc.). Child
  //    interactions are unaffected.
  void _handlePointerDown(PointerDownEvent _) {
    if (_isNavVisible) return;
    setState(() => _isNavVisible = true);
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _indexForLocation(location);

    final mediaQuery = MediaQuery.of(context);

    // Total inset a screen should leave at the bottom of its body:
    // device inset + nav reservation.
    final childBottomInset =
        mediaQuery.padding.bottom + _navReservedHeight;

    return Scaffold(
      backgroundColor: Colors.white,
      // Body extends behind the pill so content scrolls under it.
      extendBody: true,
      body: MediaQuery(
        // Override the child's padding.bottom so FABs / SafeAreas /
        // `bottom:` offsets inside a screen clear the pill.
        // Applies to the child tree only — not to the pill's own subtree.
        data: mediaQuery.copyWith(
          padding: mediaQuery.padding.copyWith(
            bottom: childBottomInset,
          ),
        ),
        // ⭐ Listener outermost: every tap on the body shows the nav.
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _handlePointerDown,
          child: NotificationListener<ScrollNotification>(
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
    // Root MediaQuery — the pill itself doesn't inherit the inflated
    // body padding (that's above the body override).
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomGap = bottomInset > 0 ? bottomInset + 4 : 18.0;

    return Container(
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