import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/screens/register_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

void main() {
  testWidgets('registration uses active school options instead of free text', (
    tester,
  ) async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/users/registration-schools');
      return http.Response(
        jsonEncode([
          {
            'uuid': '4be260c8-05bf-48bb-b7ec-f7a9e2d9cd3f',
            'school_name': 'Anita Intermediate College',
          },
          {
            'uuid': '5606a5a3-d0e2-4137-ab20-f1dad564bb27',
            'school_name': 'Second Test School',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: client, baseUrl: 'https://example.test');

    await tester.pumpWidget(MaterialApp(home: RegisterScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(find.text('School name'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text('Anita Intermediate College'), findsOneWidget);
    expect(find.text('Second Test School'), findsOneWidget);
    api.dispose();
  });
}
