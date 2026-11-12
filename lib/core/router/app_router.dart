import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/business_provider.dart';
import '../../core/providers/category_provider.dart';
import '../../core/providers/expense_provider.dart';
import '../../core/providers/product_provider.dart';
import '../../core/providers/report_provider.dart';
import '../../core/providers/sales_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/business/business_setup_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/onboarding/splash_screens.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../shared/widgets/app_shell.dart';

Future<GoRouter> createAppRouter(
    AppDatabase db, {
      String initialLocation = '/splash',
    }) async {
  final businesses = await (db.select(db.businesses)).get();
  final businessId =
  businesses.isNotEmpty ? businesses.first.id : 'default-business-id';

  // ─── Providers ───
  final authProvider = AuthProvider(db, businessId);
  final productProvider = ProductProvider(db, businessId);
  final categoryProvider = CategoryProvider(db, businessId);
  final salesProvider = SalesProvider(db, businessId);
  final reportProvider = ReportProvider(db, businessId);
  final businessProvider = BusinessProvider(db, businessId);
  final expenseProvider = ExpenseProvider(db, businessId);

  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      final isLoggedIn = authProvider.isLoggedIn;
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToSplash = state.matchedLocation == '/splash';
      final isGoingToSetup = state.matchedLocation == '/setup';

      if (!isLoggedIn &&
          !isGoingToLogin &&
          !isGoingToSplash &&
          !isGoingToSetup) {
        return '/login';
      }

      if (isLoggedIn && (isGoingToLogin || isGoingToSplash)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreens(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(authProvider: authProvider),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const BusinessSetupScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => DashboardScreen(
              businessId: businessId,
              authProvider: authProvider,
              businessProvider: businessProvider,
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) =>
                ProfileScreen(provider: businessProvider),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) =>
                SettingsScreen(provider: expenseProvider),
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) => ProductsScreen(
              provider: productProvider,
              categoryProvider: categoryProvider,
            ),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) =>
                InventoryScreen(provider: productProvider),
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => SalesScreen(
              productProvider: productProvider,
              salesProvider: salesProvider,
            ),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) =>
                ReportsScreen(provider: reportProvider),
          ),
        ],
      ),
    ],
  );
}