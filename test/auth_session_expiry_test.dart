import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ApiService _apiReturningAuthenticatedStatus(int statusCode) {
  return ApiService(
    baseUrl: 'https://example.test',
    client: MockClient((request) async {
      expect(request.headers['Authorization'], 'Bearer test-token');

      switch (request.url.path) {
        case '/users/me':
          return http.Response(
            jsonEncode({
              'uuid': 'user-1',
              'username': 'operator',
              'full_name': 'Test Operator',
              'platform_role': null,
              'is_platform_admin': false,
              'is_active': true,
            }),
            200,
          );
        case '/schools':
          return http.Response(
            jsonEncode([
              {
                'uuid': 'school-1',
                'school_code': 'SCHOOL-1',
                'school_name': 'Test School',
                'is_active': true,
              },
            ]),
            200,
          );
        case '/users/user-1/schools':
          return http.Response(
            jsonEncode([
              {
                'school_uuid': 'school-1',
                'school_name': 'Test School',
                'role': 'card_operator',
              },
            ]),
            200,
          );
        case '/schools/school-1/academic-sessions':
          return http.Response(
            jsonEncode({'detail': 'Request rejected'}),
            statusCode,
          );
        default:
          fail('Unexpected request: ${request.url}');
      }
    }),
  );
}

Future<AuthProvider> _initializedProvider(int responseStatus) async {
  SharedPreferences.setMockInitialValues({
    'access_token': 'test-token',
    'selected_school_uuid': 'school-1',
  });
  final provider = AuthProvider(
    api: _apiReturningAuthenticatedStatus(responseStatus),
  );
  await provider.initialize();
  expect(provider.isAuthenticated, isTrue);
  expect(provider.selectedSchool?.uuid, 'school-1');
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('authenticated API 401 clears the complete local session', () async {
    final provider = await _initializedProvider(401);
    final invalidated = Completer<void>();
    provider.addListener(() {
      if (!provider.isAuthenticated && !invalidated.isCompleted) {
        invalidated.complete();
      }
    });

    await expectLater(
      provider.api.getAcademicSessions('school-1'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          401,
        ),
      ),
    );
    await invalidated.future;

    final prefs = await SharedPreferences.getInstance();
    expect(provider.isAuthenticated, isFalse);
    expect(provider.selectedSchool, isNull);
    expect(provider.sessionMessage, AuthProvider.sessionExpiredMessage);
    expect(prefs.getString('access_token'), isNull);
    expect(prefs.getString('selected_school_uuid'), isNull);
    expect(prefs.getString('last_selected_school_uuid'), 'school-1');
    provider.dispose();
  });

  test('authenticated API 403 does not invalidate the session', () async {
    final provider = await _initializedProvider(403);

    await expectLater(
      provider.api.getAcademicSessions('school-1'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          403,
        ),
      ),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(provider.isAuthenticated, isTrue);
    expect(provider.selectedSchool?.uuid, 'school-1');
    expect(provider.sessionMessage, isNull);
    expect(prefs.getString('access_token'), 'test-token');
    expect(prefs.getString('selected_school_uuid'), 'school-1');
    provider.dispose();
  });
}
