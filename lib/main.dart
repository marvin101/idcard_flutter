import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/display_scale_provider.dart';
import 'screens/card_designer_route_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/landing_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/app_scale_viewport.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => DisplayScaleProvider()),
      ],
      child: MaterialApp(
        title: 'CampusID',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        builder: (context, child) =>
            AppScaleViewport(child: child ?? const SizedBox.shrink()),
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
    if (!auth.isAuthenticated) return const LandingScreen();
    return const DashboardScreen();
  }
}
