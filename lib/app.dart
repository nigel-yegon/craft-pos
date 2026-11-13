import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/database/app_database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class App extends ConsumerStatefulWidget { // Use ConsumerStatefulWidget for ref
  final AppDatabase database;
  final String initialRoute;

  const App({
    super.key,
    required this.database,
    required this.initialRoute,
  });

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  late final Future<GoRouter> _routerFuture;

  @override
  void initState() {
    super.initState();
    // Initialize the router.
    // The router will start at '/splash' or '/login' based on your logic.
    _routerFuture = createAppRouter(
      widget.database,
      initialLocation: '/splash', // Always start at splash
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GoRouter>(
      future: _routerFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // A simple loading screen while the DB/router initializes
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator())),
          );
        }

        // The router handles everything, including the Splash Screen
        return MaterialApp.router(
          title: 'Craft POS',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: snapshot.data!,
        );
      },
    );
  }
}