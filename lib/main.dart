import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/card_designer_route_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..initialize(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const _AuthGate(),
        routes: {
          CardDesignerRouteScreen.routeName: (_) =>
              const CardDesignerRouteScreen(),
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isAuthenticated) return const LoginScreen();
    return const DashboardScreen();
  }
}
