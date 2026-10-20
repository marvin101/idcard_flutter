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
  test('security events request uses authenticated paginated endpoint', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'items': [
            {
              'uuid': 'event-1',
              'event_type': 'password_changed',
              'ip_address': '127.0.0.1',
              'user_agent': 'Mozilla/5.0 Chrome/155.0 Windows NT 10.0',
              'details': {'other_sessions_revoked': true},
              'created_at': '2026-10-20T18:59:31+05:30',
            },
          ],
          'total': 3,
          'limit': 2,
          'offset': 1,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: client, baseUrl: 'https://example.test');
    api.setToken('test-access-token');

    final page = await api.getSecurityEvents(limit: 2, offset: 1);

    expect(captured.method, 'GET');
    expect(captured.url.path, '/users/me/security-events');
    expect(captured.url.queryParameters, {'limit': '2', 'offset': '1'});
    expect(captured.headers['authorization'], 'Bearer test-access-token');
    expect(page.total, 3);
    expect(page.items.single.eventType, 'password_changed');
    expect(page.items.single.details['other_sessions_revoked'], isTrue);
    expect(page.hasMore, isTrue);
    api.dispose();
  });

}
