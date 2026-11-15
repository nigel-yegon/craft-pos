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
    _routerFuture = createAppRouter(
      widget.database,
      initialLocation: widget.initialRoute,
    );
  }

  void _onSplashComplete() {
    if (mounted) setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: SplashScreens(onComplete: _onSplashComplete),
      );
    }

    return FutureBuilder<GoRouter>(
      future: _routerFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child:
                CircularProgressIndicator(color: AppTheme.heroGreen),
              ),
            ),
          );
        }

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