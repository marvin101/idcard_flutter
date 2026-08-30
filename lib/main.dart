import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'providers/auth_provider.dart';
import 'providers/display_scale_provider.dart';
import 'screens/card_designer_route_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/public_information_screens.dart';
import 'screens/register_screen.dart';
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
        routes: {
          AppRoutes.landing: (_) => const LandingScreen(),
          AppRoutes.signIn: (_) => const _AuthRoute(
            authenticated: DashboardScreen(),
            unauthenticated: LoginScreen(),
          ),
          AppRoutes.register: (context) => _AuthRoute(
            authenticated: const DashboardScreen(),
            unauthenticated: RegisterScreen(
              api: context.read<AuthProvider>().api,
            ),
          ),
          AppRoutes.dashboard: (_) => const _AuthRoute(
            authenticated: DashboardScreen(),
            unauthenticated: LoginScreen(),
          ),
          AppRoutes.privacy: (_) => const PrivacyScreen(),
          AppRoutes.terms: (_) => const TermsScreen(),
          AppRoutes.support: (_) => const SupportScreen(),
          CardDesignerRouteScreen.routeName: (_) => const _AuthRoute(
            authenticated: CardDesignerRouteScreen(),
            unauthenticated: LoginScreen(),
          ),
        },
        onUnknownRoute: (_) => MaterialPageRoute<void>(
          settings: const RouteSettings(name: AppRoutes.landing),
          builder: (_) => const LandingScreen(),
        ),
      ),
    );
  }
}

class _AuthRoute extends StatelessWidget {
  const _AuthRoute({
    required this.authenticated,
    required this.unauthenticated,
  });

  final Widget authenticated;
  final Widget unauthenticated;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return auth.isAuthenticated ? authenticated : unauthenticated;
  }
}
