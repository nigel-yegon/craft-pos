// lib/core/router/app_router.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/business_provider.dart';
import '../providers/category_provider.dart';
import '../providers/database_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/product_provider.dart';
import '../providers/report_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/trial_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/business/business_setup_screen.dart';
import '../../features/dashboard/dashboard_screen.dart' show DashboardScreen;
import '../../features/inventory/inventory_screen.dart';
import '../../features/inventory/stock_report_screen.dart';
import '../../features/onboarding/splash_screens.dart';
import '../../features/onboarding/trial_expired_screen.dart'; // ⭐ NEW
import '../../features/profile/profile_screen.dart';
import '../../features/products/products_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/reports/transactions_screen.dart';
import '../../features/sales/held_orders_screen.dart';
import '../../features/sales/sales_screen.dart';
import '../../features/settings/aob_screen.dart';
import '../../features/settings/backup_screen.dart';
import '../../features/settings/expenses_screen.dart';
import '../../features/settings/notifications_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/subscription_screen.dart' show SubscriptionScreen;
import '../../shared/widgets/app_shell.dart';

/// Riverpod Provider that builds the router.
///
/// Watches auth + business + trial state so the router re-evaluates the
/// redirect closure whenever any of those change (login, logout, setup
/// completion, subscription activation).
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final businessAsync = ref.watch(currentBusinessProvider);
  final trial = ref.watch(trialStatusProvider);

  final db = ref.watch(databaseProvider);
  final business = businessAsync.value;
  final businessId = business?.id ?? 'default-business-id';

  // These providers are still manually constructed to match the old
  // screen constructors. They rebuild whenever the router rebuilds
  // (i.e., when auth / business / trial state changes).
  final productProvider = ProductProvider(db, businessId);
  final categoryProvider = CategoryProvider(db, businessId);
  final salesProvider = SalesProvider(db, businessId);
  final reportProvider = ReportProvider(db, businessId);
  final businessProvider = BusinessProvider(db, businessId);
  final expenseProvider = ExpenseProvider(db, businessId);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final isGoingToSplash = state.matchedLocation == '/splash';
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToSetup = state.matchedLocation == '/setup';
      final isGoingToTrialExpired =
          state.matchedLocation == '/trial-expired';
      final isGoingToSubscription =
      state.matchedLocation.startsWith('/settings/subscription');

      // 1. Wait for business stream to resolve.
      if (businessAsync.isLoading) {
        return isGoingToSplash ? null : '/splash';
      }

      final hasBusiness = businessAsync.value != null;
      final isLoggedIn = auth.isLoggedIn;

      // 2. No business → setup.
      if (!hasBusiness) {
        return isGoingToSetup ? null : '/setup';
      }

      // 3. Business exists but user isn't logged in → login.
      if (!isLoggedIn) {
        return isGoingToLogin ? null : '/login';
      }

      // 4. ⭐ Trial hard-lock: expired + no subscription = locked.
      if (trial.isLocked) {
        if (!isGoingToTrialExpired && !isGoingToSubscription) {
          return '/trial-expired';
        }
        return null;
      }

      // 5. Logged in, trying to go to login/setup/splash/trial-expired
      //    → route to dashboard.
      if (isLoggedIn &&
          (isGoingToLogin ||
              isGoingToSetup ||
              isGoingToSplash ||
              isGoingToTrialExpired)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final businessAsync = ref.watch(currentBusinessProvider);
            final hasBusiness = businessAsync.value != null;
            return SplashScreens(
              isFirstRun: !hasBusiness,
              onComplete: () {
                // Redirect handles navigation once state resolves.
              },
            );
          },
        ),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(authProvider: auth),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const BusinessSetupScreen(),
      ),
      GoRoute(
        path: '/trial-expired',
        builder: (context, state) => const TrialExpiredScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => DashboardScreen(
              businessId: businessId,
              authProvider: auth,
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
                  authProvider: auth,
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
          ),
        ],
      ),
    ],
  );
});