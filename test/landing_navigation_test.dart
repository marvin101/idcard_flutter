import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/screens/landing_screen.dart';
import 'package:idcard_flutter/screens/login_screen.dart';
import 'package:idcard_flutter/screens/public_information_screens.dart';
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
            AppRoutes.privacy: (_) => const PrivacyScreen(),
            AppRoutes.terms: (_) => const TermsScreen(),
            AppRoutes.support: (_) => const SupportScreen(),
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

  testWidgets('Privacy and Terms public routes resolve', (tester) async {
    await pumpLandingPage(tester);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.privacy);
    await tester.pumpAndSettle();
    expect(find.byType(PrivacyScreen), findsOneWidget);

    navigator.pushReplacementNamed(AppRoutes.terms);
    await tester.pumpAndSettle();
    expect(find.byType(TermsScreen), findsOneWidget);
  });

  testWidgets('Landing footer exposes public information links', (
    tester,
  ) async {
    await pumpLandingPage(tester);

    final supportLink = find.byKey(const Key('footer-support-link'));
    await tester.scrollUntilVisible(supportLink, 800);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('footer-privacy-link')), findsOneWidget);
    expect(find.byKey(const Key('footer-terms-link')), findsOneWidget);
    expect(supportLink, findsOneWidget);

    await tester.tap(supportLink);
    await tester.pumpAndSettle();
    expect(find.byType(SupportScreen), findsOneWidget);
  });
}
