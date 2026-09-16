import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/navigation/app_router.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/screens/login_screen.dart';
import 'package:idcard_flutter/screens/register_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/authenticated_app_bar.dart';
import 'package:idcard_flutter/widgets/campus_home_link.dart';
import 'package:provider/provider.dart';

class SessionAuth extends AuthProvider {
  SessionAuth({required super.api});
  @override
  bool get isAuthenticated => true;
}

void main() {
  late ApiService api;
  late AuthProvider auth;
  late AppRouterDelegate router;
  late Completer<http.Response> response;
  late int posts;
  late Map<String, dynamic> payload;

  setUp(() {
    posts = 0;
    api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          expect(request.url.path, '/users/registration-schools');
          return http.Response(
            jsonEncode([
              {'uuid': 'school-1', 'school_name': 'Test school'},
            ]),
            200,
          );
        }
        posts++;
        expect(request.url.path, '/users/register');
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return response.future;
      }),
    );
    auth = AuthProvider(api: api);
  });
  tearDown(() {
    auth.dispose();
  });

  Future<void> pump(WidgetTester tester, String route) async {
    response = Completer<http.Response>();
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (route == AppRoutes.dashboard) {
      auth.dispose();
      api = ApiService(baseUrl: 'https://example.test');
      auth = SessionAuth(api: api);
    }
    router = AppRouterDelegate(
      (location, arguments) => switch (location) {
        AppRoutes.register => RegisterScreen(api: api),
        AppRoutes.signIn => const LoginScreen(),
        AppRoutes.dashboard => Scaffold(
          appBar: const AuthenticatedAppBar(title: Text('Workspace')),
        ),
        _ => const Scaffold(body: Text('Public homepage')),
      },
    );
    await router.setNewRoutePath(AppRouteState(route));
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
          routeInformationProvider: PlatformRouteInformationProvider(
            initialRouteInformation: RouteInformation(uri: Uri.parse(route)),
          ),
          routerDelegate: router,
          routeInformationParser: const AppRouteInformationParser(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillValid(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    for (final entry in {
      0: 'Test User',
      1: 'test_user',
      2: ' test@example.test ',
      4: 'Teacher',
      5: 'password123',
      6: 'password123',
    }.entries) {
      await tester.enterText(fields.at(entry.key), entry.value);
    }
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test school').last);
    await tester.pumpAndSettle();
  }

  testWidgets('sign in exposes Register and routes to the registration page', (
    tester,
  ) async {
    await pump(tester, AppRoutes.signIn);
    await tester.tap(find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();
    expect(router.currentLocation, AppRoutes.register);
    expect(find.text('Create your CampusID account'), findsOneWidget);
  });

  testWidgets(
    'direct register Sign in goes to sign in without requiring a parent',
    (tester) async {
      await pump(tester, AppRoutes.register);
      await tester.tap(find.text('Already registered? Sign in'));
      await tester.pumpAndSettle();
      expect(router.currentLocation, AppRoutes.signIn);
      expect(find.byType(LoginScreen), findsOneWidget);
    },
  );

  for (final route in [
    AppRoutes.signIn,
    AppRoutes.register,
    AppRoutes.dashboard,
  ]) {
    testWidgets('logo from $route goes home and back restores the page', (
      tester,
    ) async {
      await pump(tester, route);
      final originalAuth = auth.isAuthenticated;
      await tester.tap(find.byType(CampusHomeLink));
      await tester.pumpAndSettle();
      expect(router.currentLocation, AppRoutes.landing);
      expect(find.text('Public homepage'), findsOneWidget);
      expect(auth.isAuthenticated, originalAuth);
      await router.popRoute();
      await tester.pumpAndSettle();
      expect(router.currentLocation, route);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('invalid registration input stays local', (tester) async {
    await pump(tester, AppRoutes.register);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your name.'), findsOneWidget);
    expect(find.text('Select your school.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(2), 'invalid');
    await tester.enterText(find.byType(TextFormField).at(5), 'short');
    await tester.enterText(find.byType(TextFormField).at(6), 'different');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Use at least 8 characters.'), findsOneWidget);
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(posts, 0);
  });

  testWidgets(
    'pending request blocks repeated Enter and 201 continues to sign in',
    (tester) async {
      await pump(tester, AppRoutes.register);
      await fillValid(tester);
      await tester.tap(find.text('Create account'));
      await tester.pump();
      final confirm = tester.widget<TextField>(find.byType(TextField).last);
      confirm.onSubmitted!('password123');
      confirm.onSubmitted!('password123');
      await tester.pump();
      expect(posts, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(payload['school_uuid'], 'school-1');
      expect(payload['email'], 'test@example.test');
      expect(payload.containsKey('role'), isFalse);
      response.complete(http.Response('{"full_name":"Test User"}', 201));
      await tester.pumpAndSettle();
      expect(find.text('Welcome, Test User!'), findsOneWidget);
      expect(auth.isAuthenticated, isFalse);
      await tester.tap(find.text('Continue to sign in'));
      await tester.pumpAndSettle();
      expect(router.currentLocation, AppRoutes.signIn);
    },
  );

  for (final status in [409, 422, 500]) {
    testWidgets('API $status is visible and releases loading state', (
      tester,
    ) async {
      await pump(tester, AppRoutes.register);
      await fillValid(tester);
      await tester.tap(find.text('Create account'));
      await tester.pump();
      response.complete(
        http.Response(
          jsonEncode({'detail': 'Registration rejected ($status)'}),
          status,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Registration rejected ($status)'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Create account'),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }

  test('clean public paths parse and restore without redirecting', () async {
    const parser = AppRouteInformationParser();
    for (final path in ['/', '/sign-in', '/register']) {
      final state = await parser.parseRouteInformation(
        RouteInformation(uri: Uri.parse(path)),
      );
      expect(state.location, path);
      expect(parser.restoreRouteInformation(state).uri.path, path);
    }
  });
}
