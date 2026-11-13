import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _tabs = [
    ('/dashboard', Icons.home_outlined, Icons.home, 'Home'),
    ('/products', Icons.storefront_outlined, Icons.storefront, 'Products'),
    ('/inventory', Icons.inventory_2_outlined, Icons.inventory_2, 'Inventory'),
    ('/sales', Icons.shopping_cart_outlined, Icons.shopping_cart, 'Sales'),
    ('/reports', Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
  ];

  int _indexForLocation(String location) {
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].$1)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final currentIndex = _indexForLocation(location);

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: slide, child: child),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(location),
          child: child,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (index) {
            final target = _tabs[index].$1;
            if (target != location) {
              context.go(target);
            }
          },
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF00897B).withValues(alpha: 0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: _tabs.map((t) {
            return NavigationDestination(
              icon: Icon(t.$2),
              selectedIcon: Icon(t.$3, color: const Color(0xFF00897B)),
              label: t.$4,
            );
          }).toList(),
        ),
      ),
    );
  }
}