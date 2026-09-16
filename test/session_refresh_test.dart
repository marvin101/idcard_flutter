import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/providers/api_student_form_provider.dart';
import 'package:idcard_flutter/screens/student_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

String token(String marker, {bool expired = false}) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + (expired ? -60 : 3600), 'marker': marker}))).replaceAll('=', '')}.signature';
http.Response renewed(String access) => http.Response(
  jsonEncode({
    'access_token': access,
    'refresh_token': 'replacement-refresh',
    'token_type': 'bearer',
  }),
  200,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'concurrent 401 calls share refresh and retry original requests once',
    () async {
      final old = token('old'), next = token('next');
      var refreshes = 0, oldRequests = 0, newRequests = 0;
      final gate = Completer<void>();
      final api = ApiService(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path == '/auth/refresh') {
            refreshes++;
            await gate.future;
            return renewed(next);
          }
          if (request.headers['Authorization'] == 'Bearer $old') {
            oldRequests++;
            return http.Response('{"detail":"expired"}', 401);
          }
          expect(request.headers['Authorization'], 'Bearer $next');
          newRequests++;
          return http.Response('[]', 200);
        }),
      );
      api.setToken(old);
      api.setRefreshToken('initial-refresh');
      final requests = Future.wait(
        List.generate(5, (_) => api.getAcademicSessions('school')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      gate.complete();
      await requests;
      expect(refreshes, 1);
      expect(oldRequests, 5);
      expect(newRequests, 5);
      api.dispose();
    },
  );

  test(
    'expired access renews before sending and refresh failure invalidates once',
    () async {
      final next = token('next');
      var refreshes = 0, invalidations = 0;
      final api = ApiService(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path == '/auth/refresh') {
            refreshes++;
            return refreshes == 1
                ? renewed(next)
                : http.Response('{"detail":"invalid"}', 401);
          }
          expect(request.headers['Authorization'], 'Bearer $next');
          return http.Response('[]', 200);
        }),
      );
      api.setSessionInvalidatedCallback(() {
        invalidations++;
      });
      api.setToken(token('expired', expired: true));
      api.setRefreshToken('refresh');
      await api.getAcademicSessions('school');
      expect(refreshes, 1);
      expect(invalidations, 0);
      api.setToken(token('expired-again', expired: true));
      api.setRefreshToken('refresh');
      await expectLater(
        api.getAcademicSessions('school'),
        throwsA(isA<ApiException>()),
      );
      expect(invalidations, 1);
      api.dispose();
    },
  );

  test(
    'a temporary refresh outage preserves authentication for retry',
    () async {
      var invalidations = 0;
      final api = ApiService(
        baseUrl: 'https://example.test',
        client: MockClient(
          (request) async => http.Response('{"detail":"unavailable"}', 503),
        ),
      );
      api.setSessionInvalidatedCallback(() {
        invalidations++;
      });
      api.setToken(token('expired', expired: true));
      api.setRefreshToken('refresh');
      await expectLater(
        api.getAcademicSessions('school'),
        throwsA(isA<http.ClientException>()),
      );
      expect(invalidations, 0);
      api.dispose();
    },
  );

  test(
    'retry stops after one renewal if replacement access is rejected',
    () async {
      var refreshes = 0, calls = 0, invalidations = 0;
      final api = ApiService(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          if (request.url.path == '/auth/refresh') {
            refreshes++;
            return renewed(token('new'));
          }
          calls++;
          return http.Response('{"detail":"invalid"}', 401);
        }),
      );
      api.setSessionInvalidatedCallback(() {
        invalidations++;
      });
      api.setToken(token('old'));
      api.setRefreshToken('refresh');
      await expectLater(
        api.getAcademicSessions('school'),
        throwsA(isA<ApiException>()),
      );
      expect(refreshes, 1);
      expect(calls, 2);
      expect(invalidations, 1);
      api.dispose();
    },
  );

  testWidgets(
    'silent renewal keeps real student form draft and provider instance',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final old = token('old'), next = token('new');
      var refreshes = 0;
      final api = ApiService(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          switch (request.url.path) {
            case '/auth/login':
              return http.Response(
                jsonEncode({'access_token': old, 'refresh_token': 'refresh'}),
                200,
              );
            case '/auth/refresh':
              refreshes++;
              return renewed(next);
            case '/users/me':
              return http.Response(
                jsonEncode({
                  'uuid': 'user',
                  'username': 'worker',
                  'full_name': 'Worker',
                  'is_platform_admin': true,
                  'platform_role': 'platform_admin',
                  'is_active': true,
                }),
                200,
              );
            case '/schools':
              return http.Response(
                jsonEncode([
                  {
                    'uuid': 'school',
                    'school_name': 'Test',
                    'school_code': 'TEST',
                    'is_active': true,
                  },
                ]),
                200,
              );
            default:
              return http.Response('[]', 200);
          }
        }),
      );
      final auth = AuthProvider(api: api);
      await auth.login('worker', 'password');
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: const MaterialApp(home: _FormHost()),
        ),
      );
      await tester.pumpAndSettle();
      final element = tester.element(find.byType(StudentFormScreen));
      final provider = Provider.of<ApiStudentFormProvider>(
        tester.element(find.byType(Form)),
        listen: false,
      );
      provider.fullNameController.text = 'Unsaved long entry';
      provider.admissionNoController.text = 'DRAFT';
      // Simulate the access token having elapsed beyond 30 minutes.
      api.setToken(token('elapsed', expired: true));
      api.setRefreshToken('refresh');
      await api.getAcademicSessions('school');
      await tester.pumpAndSettle();
      expect(auth.isAuthenticated, isTrue);
      expect(refreshes, 1);
      expect(
        identical(element, tester.element(find.byType(StudentFormScreen))),
        isTrue,
      );
      expect(provider.fullNameController.text, 'Unsaved long entry');
      expect(provider.admissionNoController.text, 'DRAFT');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('refresh_token'), 'replacement-refresh');
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    },
  );
}

class _FormHost extends StatelessWidget {
  const _FormHost();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return StudentFormScreen(schoolUuid: 'school', api: auth.api);
  }
}
