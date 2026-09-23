import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/screens/login_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:provider/provider.dart';

class _SuccessfulAuthProvider extends AuthProvider {
  @override
  Future<void> login(String username, String password) async {}
}

class _FailedAuthProvider extends AuthProvider {
  @override
  String? get error => 'Invalid username or password.';

  @override
  Future<void> login(String username, String password) async {
    throw const ApiException(401, 'Invalid username or password.');
  }
}

void main() {
  testWidgets('successful sign in replaces history with dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _SuccessfulAuthProvider(),
        child: MaterialApp(
          routes: {
            AppRoutes.landing: (_) =>
                const Scaffold(body: Center(child: Text('Landing route'))),
            AppRoutes.signIn: (_) => const LoginScreen(),
            AppRoutes.dashboard: (_) =>
                const Scaffold(body: Center(child: Text('Dashboard route'))),
          },
          initialRoute: AppRoutes.signIn,
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'operator');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard route'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Landing route'), findsNothing);
  });

  testWidgets('failed sign in keeps credentials usable and shows the error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _FailedAuthProvider(),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'operator');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(find.text('Invalid username or password.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('operator'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('registration link still opens the registration route', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          routes: {
            AppRoutes.signIn: (_) => const LoginScreen(),
            AppRoutes.register: (_) =>
                const Scaffold(body: Text('Registration route')),
          },
          initialRoute: AppRoutes.signIn,
        ),
      ),
    );

    await tester.tap(find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();

    expect(find.text('Registration route'), findsOneWidget);
  });
}
