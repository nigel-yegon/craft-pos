import 'package:flutter/material.dart';
import 'core/database/app_database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class App extends StatelessWidget {
  final AppDatabase database;
  final String initialRoute;

  const App({
    super.key,
    required this.database,
    required this.initialRoute,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: createAppRouter(database, initialLocation: initialRoute),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

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