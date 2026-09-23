import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/screens/platform_administration_screen.dart';
import 'package:idcard_flutter/screens/student_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'admin UI creates schools and accounts and confirms school activation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final schools = <Map<String, dynamic>>[
        {
          'uuid': 'school',
          'school_name': 'Inactive school',
          'school_code': 'TEST',
          'is_active': false,
        },
      ];
      final accounts = <Map<String, dynamic>>[];
      var activations = 0;
      var rejectNextAccountUpdate = false;
      final accountUpdates = <Map<String, dynamic>>[];
      final api = ApiService(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          switch (request.url.path) {
            case '/auth/login':
              return http.Response('{"access_token":"token"}', 200);
            case '/users/me':
              return http.Response(
                '{"uuid":"admin","username":"admin","full_name":"Admin","is_platform_admin":true,"platform_role":"platform_admin","is_active":true}',
                200,
              );
            case '/schools':
              if (request.method == 'POST') {
                final body = jsonDecode(request.body) as Map<String, dynamic>;
                schools.add({...body, 'uuid': 'new-school', 'is_active': true});
                return http.Response(jsonEncode(schools.last), 201);
              }
              return http.Response(
                jsonEncode(
                  request.url.queryParameters['include_inactive'] == 'true'
                      ? schools
                      : schools.where((s) => s['is_active'] == true).toList(),
                ),
                200,
              );
            case '/schools/school/activation':
              activations++;
              schools[0]['is_active'] =
                  (jsonDecode(request.body)
                      as Map<String, dynamic>)['is_active'];
              return http.Response(jsonEncode(schools[0]), 200);
            case '/users':
              return http.Response(jsonEncode(accounts), 200);
            case '/users/accounts':
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              accounts.add({
                ...body..remove('password'),
                'uuid': 'new-user',
                'is_active': true,
                'is_platform_admin': body['platform_role'] == 'platform_admin',
              });
              return http.Response(jsonEncode(accounts.last), 201);
            case '/users/new-user/account':
              if (rejectNextAccountUpdate) {
                rejectNextAccountUpdate = false;
                return http.Response(
                  '{"detail":"The last active platform administrator must be retained"}',
                  409,
                  headers: {'content-type': 'application/json'},
                );
              }
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              accountUpdates.add(body);
              accounts[0].addAll(body);
              accounts[0]['is_platform_admin'] =
                  accounts[0]['platform_role'] == 'platform_admin';
              return http.Response(jsonEncode(accounts[0]), 200);
            default:
              throw StateError('Unexpected ${request.method} ${request.url}');
          }
        }),
      );
      final auth = AuthProvider(api: api);
      await auth.login('admin', 'password');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(home: PlatformAdministrationScreen(api: api)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inactive school'), findsOneWidget);
      await tester.tap(find.text('Activate'));
      await tester.pumpAndSettle();
      expect(activations, 0);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(activations, 1);
      await tester.tap(find.text('Create school'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('admin-school_code')),
        'NEW',
      );
      await tester.enterText(
        find.byKey(const ValueKey('admin-school_name')),
        'New school',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('New school'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Accounts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('admin-username')),
        'worker',
      );
      await tester.enterText(
        find.byKey(const ValueKey('admin-full_name')),
        'New worker',
      );
      await tester.enterText(
        find.byKey(const ValueKey('admin-password')),
        'password123',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-platform_role')),
      );
      await tester.tap(find.byKey(const ValueKey('admin-platform_role')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Platform administrator').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('New worker'), findsOneWidget);
      expect(find.textContaining('Platform Admin'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demote to regular user'));
      await tester.pumpAndSettle();
      expect(accountUpdates, isEmpty);
      expect(find.text('Demote platform administrator?'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(accountUpdates.last['platform_role'], isNull);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Promote to platform administrator'));
      await tester.pumpAndSettle();
      expect(find.text('Promote to platform administrator?'), findsOneWidget);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(accountUpdates.last['platform_role'], 'platform_admin');

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate account'));
      await tester.pumpAndSettle();
      expect(find.text('Deactivate account?'), findsOneWidget);
      expect(
        find.textContaining('last active platform administrator'),
        findsOneWidget,
      );
      rejectNextAccountUpdate = true;
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(
        find.text('The last active platform administrator must be retained'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );

  testWidgets('platform administration controls are hidden from regular users', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/auth/login':
            return http.Response('{"access_token":"token"}', 200);
          case '/users/me':
            return http.Response(
              '{"uuid":"worker","username":"worker","full_name":"Worker","is_platform_admin":false,"platform_role":null,"is_active":true}',
              200,
            );
          case '/schools':
            if (request.url.queryParameters['include_inactive'] != 'true') {
              return http.Response('[]', 200);
            }
            return http.Response(
              '{"detail":"Platform administrator required"}',
              403,
            );
          case '/users/worker/schools':
            return http.Response('[]', 200);
          case '/users':
            return http.Response(
              '{"detail":"Platform administrator required"}',
              403,
            );
          default:
            throw StateError('Unexpected ${request.method} ${request.url}');
        }
      }),
    );
    final auth = AuthProvider(api: api);
    await auth.login('worker', 'password');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(home: PlatformAdministrationScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Platform administrator access required.'),
      findsOneWidget,
    );
    expect(find.text('Create account'), findsNothing);
    expect(find.text('Accounts'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });

  testWidgets('student list requests bounded pages and searches on server', (
    tester,
  ) async {
    final requests = <Uri>[];
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/students/paged')) {
          requests.add(request.url);
          return http.Response(
            jsonEncode({
              'items': [],
              'total': 201,
              'offset': int.parse(request.url.queryParameters['offset']!),
              'limit': 100,
              'has_more': request.url.queryParameters['offset'] == '0',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/students')) {
          throw StateError('Unbounded list requested');
        }
        return http.Response('[]', 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StudentsScreen(
          schoolUuid: 'school',
          schoolName: 'Test',
          api: api,
          canEdit: false,
          canDelete: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests.single.queryParameters['limit'], '100');
    await tester.ensureVisible(find.byKey(const Key('students-next-page')));
    await tester.tap(find.byKey(const Key('students-next-page')));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['offset'], '100');
    await tester.enterText(find.byType(TextField).first, 'needle');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(requests.last.queryParameters['search'], 'needle');
    expect(requests.last.queryParameters['offset'], '0');
    await tester.pumpWidget(const SizedBox.shrink());
    api.dispose();
  });
}
