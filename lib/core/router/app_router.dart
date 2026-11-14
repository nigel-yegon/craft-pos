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
import '../../features/inventory/stock_report_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/sales/held_orders_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/settings/aob_screen.dart';
import '../../features/settings/backup_screen.dart';
import '../../features/settings/expenses_screen.dart';
import '../../features/settings/notifications_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/subscription_screen.dart';
import '../../shared/widgets/app_shell.dart';
import '../../features/reports/transactions_screen.dart';

// (imports — keep all existing ones, ensure stock_report_screen.dart is present)
import '../../features/inventory/inventory_screen.dart';
import '../../features/inventory/stock_report_screen.dart';   // ⭐ must be present
// ... other imports ...

// Inside the /reports GoRoute's routes:


Future<GoRouter> createAppRouter(
    AppDatabase db, {
      String initialLocation = '/dashboard',
    }) async {
  final businesses = await (db.select(db.businesses)).get();
  final businessId =
  businesses.isNotEmpty ? businesses.first.id : 'default-business-id';

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
      final isGoingToSetup = state.matchedLocation == '/setup';

      // If not logged in and not going to login/setup, force login
      if (!isLoggedIn && !isGoingToLogin && !isGoingToSetup) {
        return '/login';
      }
      // If logged in and trying to access login, go to dashboard
      if (isLoggedIn && isGoingToLogin) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
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

          // ⭐ Settings Routes — duplicate 'backup' route removed
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(
                path: 'expenses',
                builder: (context, state) =>
                    ExpensesScreen(provider: expenseProvider),
              ),
              GoRoute(
                path: 'subscription',
                builder: (context, state) => const SubscriptionScreen(),
              ),
              GoRoute(
                path: 'aob',
                builder: (context, state) => AobScreen(
                  businessProvider: businessProvider,
                  authProvider: authProvider,
                ),
              ),
              GoRoute(
                path: 'notifications',
                builder: (context, state) => const NotificationsScreen(),
              ),
              GoRoute(
                path: 'backup',
                builder: (context, state) => const BackupScreen(),
              ),
            ],
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
              categoryProvider: categoryProvider,
            ),
            routes: [
              GoRoute(
                path: 'held',
                builder: (context, state) =>
                    HeldOrdersScreen(provider: salesProvider),
              ),
            ],
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) =>
                ReportsScreen(provider: reportProvider),
            routes: [
              // Inside the /reports GoRoute's routes: [...]
              GoRoute(
                path: 'stock',
                builder: (context, state) {
                  final extra = state.extra;
                  final initialTab = (extra is int) ? extra : 0;
                  return StockReportScreen(
                    provider: productProvider,
                    initialTab: initialTab,
                  );
                },
              ),
              GoRoute(
                path: 'transactions',
                builder: (context, state) =>
                    TransactionsScreen(provider: reportProvider),
              ),
            ],
          ),     ],
      ),
    ],
  );
}