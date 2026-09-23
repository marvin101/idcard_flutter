import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/screens/login_screen.dart';
import 'package:provider/provider.dart';

class _SuccessfulAuthProvider extends AuthProvider {
  @override
  Future<void> login(String username, String password) async {}
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
}
