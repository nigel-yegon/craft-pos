import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/database/app_database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/splash_screens.dart';

class App extends StatefulWidget {
  final AppDatabase database;
  final String initialRoute;

  const App({
    super.key,
    required this.database,
    required this.initialRoute,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final Future<GoRouter> _routerFuture;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    // 1. Initialize the router asynchronously.
    // It will load the database, find the businessId, and build the routes.
    _routerFuture = createAppRouter(
      widget.database,
      initialLocation: widget.initialRoute,
    );
  }

  void _onSplashComplete() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // ═══ PHASE 1: SPLASH SCREEN ═══
    // We keep the user on this screen while the router is loading.
    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: SplashScreens(
          onComplete: _onSplashComplete,
        ),
      );
    }

    // ═══ PHASE 2: MAIN APP ═══
    // By now, the splash screen has finished its animation.
    // We resolve the router future and launch the app.
    return FutureBuilder<GoRouter>(
      future: _routerFuture,
      builder: (context, snapshot) {
        // If the router is somehow still loading (e.g., slow device),
        // show a simple white screen briefly before the app loads.
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.heroGreen),
              ),
            ),
          );
        }

        // Router is ready, launch the main application
        return MaterialApp.router(
          title: 'Craft Business',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: snapshot.data!,
        );
      },
    );
  }
}