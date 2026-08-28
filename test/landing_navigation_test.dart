import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/screens/landing_screen.dart';
import 'package:idcard_flutter/screens/login_screen.dart';
import 'package:idcard_flutter/screens/register_screen.dart';
import 'package:provider/provider.dart';

void main() {
  Future<void> pumpLandingPage(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          routes: {
            AppRoutes.landing: (_) => const LandingScreen(),
            AppRoutes.signIn: (_) => const LoginScreen(),
            AppRoutes.register: (context) =>
                RegisterScreen(api: context.read<AuthProvider>().api),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Get started opens registration', (tester) async {
    await pumpLandingPage(tester);

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Create your CampusID account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
  });

  testWidgets('Sign in opens login', (tester) async {
    await pumpLandingPage(tester);

    await tester.tap(find.text('Sign in').first);
    await tester.pumpAndSettle();

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(LandingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });
}
