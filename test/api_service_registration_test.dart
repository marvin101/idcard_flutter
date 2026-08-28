import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/services/api_service.dart';

void main() {
  test('registration schools use the public options endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/users/registration-schools');
      expect(request.headers.containsKey('authorization'), isFalse);
      return http.Response(
        jsonEncode([
          {
            'uuid': '4be260c8-05bf-48bb-b7ec-f7a9e2d9cd3f',
            'school_name': 'Anita Intermediate College',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: client, baseUrl: 'https://example.test');

    final schools = await api.getRegistrationSchools();

    expect(schools, hasLength(1));
    expect(
      (schools.single as Map<String, dynamic>)['school_name'],
      'Anita Intermediate College',
    );
    api.dispose();
  });

  test('registration sends the selected school UUID', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/users/register');
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'uuid': '4be260c8-05bf-48bb-b7ec-f7a9e2d9cd3f',
          'username': 'new.user',
          'full_name': 'New User',
          'email': null,
          'mobile': '9000000000',
          'designation': 'Teacher',
          'platform_role': null,
          'is_platform_admin': false,
          'is_active': true,
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: client, baseUrl: 'https://example.test');

    final result = await api.register(
      username: 'new.user',
      password: 'password123',
      fullName: 'New User',
      schoolUuid: '4be260c8-05bf-48bb-b7ec-f7a9e2d9cd3f',
      email: '  ',
      mobile: '9000000000',
      designation: 'Teacher',
    );

    expect(requestBody['username'], 'new.user');
    expect(requestBody['full_name'], 'New User');
    expect(requestBody['school_uuid'], '4be260c8-05bf-48bb-b7ec-f7a9e2d9cd3f');
    expect(requestBody['email'], isNull);
    expect(requestBody.containsKey('school_name'), isFalse);
    expect(requestBody.containsKey('role'), isFalse);
    expect(result['is_active'], isTrue);
    api.dispose();
  });
}
