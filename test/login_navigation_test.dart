import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/screens/login_screen.dart';
import 'package:provider/provider.dart';

class _SuccessfulAuthProvider extends AuthProvider {
  @override
  Future<void> login(String username, String password) async {}
}

void main() {
  testWidgets('successful sign in closes the login route', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _SuccessfulAuthProvider(),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                ),
                child: const Text('Open login'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open login'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'operator');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Open login'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
