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

  // ⭐ Height reserved *inside the body* for the floating pill.
  //    A screen's own FloatingActionButton / bottom: offset / SafeArea will
  //    automatically clear the pill because the body's MediaQuery.padding.bottom
  //    is set to this value.
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

    final mediaQuery = MediaQuery.of(context);

    // ⭐ Total inset a screen should leave at the bottom of its body:
    //    - the real device inset (gesture bar / home indicator)
    //    - PLUS the nav reservation (pill + breathing room)
    //    This is what FABs, SafeAreas, and `bottom:` offsets inside a screen
    //    will use to position themselves above the pill.
    final childBottomInset =
        mediaQuery.padding.bottom + _navReservedHeight;

    return Scaffold(
      backgroundColor: Colors.white,
      // ⭐ Body extends behind the pill so content scrolls *under* it.
      //    The pill's visual "float" comes from this + the pill's shadow.
      extendBody: true,
      body: MediaQuery(
        // Override the child's padding.bottom so any FAB / SafeArea / bottom
        // offset inside a screen sits above the pill — no per-screen patches.
        // The override applies to the *child tree only* (this MediaQuery wraps
        // only `body`, not the pill's own subtree below).
        data: mediaQuery.copyWith(
          padding: mediaQuery.padding.copyWith(
            bottom: childBottomInset,
          ),
        ),
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
      bottomNavigationBar: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: _isNavVisible ? Offset.zero : const Offset(0, 1.5),
        child: _buildFloatingNav(currentIndex),
      ),
    );
  }

  Widget _buildFloatingNav(int currentIndex) {
    // ⚠️ Use the *root* MediaQuery (the one outside the body override) so the
    //    pill itself doesn't inherit the inflated padding.bottom. If we used
    //    MediaQuery.of(context) here it would be the shell's own context —
    //    which is above the body override, so this is actually correct, but
    //    we make it explicit by reading the shell-level padding.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomGap = bottomInset > 0 ? bottomInset + 4 : 18.0;

    return Container(
      // ⭐ Soft green gradient strip behind the pill — hides any white bleed
      //    from the scaffold body while keeping the pill floating.
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