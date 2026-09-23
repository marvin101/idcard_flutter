import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/services/api_service.dart';

void main() {
  test('self-profile update submits username and normalized email', () async {
    late Map<String, dynamic> requestBody;
    final client = MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/users/me');
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'uuid': 'user-1',
          'username': 'updated.user',
          'full_name': 'Updated User',
          'email': 'updated@example.com',
          'mobile': null,
          'is_platform_admin': false,
          'is_active': true,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: client, baseUrl: 'https://example.test');

    await api.updateMe(
      username: ' updated.user ',
      fullName: ' Updated User ',
      email: ' updated@example.com ',
      mobile: ' ',
    );

    expect(requestBody, {
      'username': 'updated.user',
      'full_name': 'Updated User',
      'email': 'updated@example.com',
      'mobile': null,
    });
    api.dispose();
  });
}
