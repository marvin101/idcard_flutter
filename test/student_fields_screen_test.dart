import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/screens/student_fields_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

void main() {
  testWidgets('renders student fields after loading inside MainLayout', (
    tester,
  ) async {
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path == '/schools/school-1/student-field-config') {
          return http.Response(
            '{"fields":[{"key":"full_name","label":"Full name","data_type":"text","enabled":true,"required":true,"protected":true,"display_order":0},{"key":"aadhaar","label":"Aadhaar","data_type":"text","enabled":true,"required":true,"protected":false,"display_order":1}]}',
            200,
          );
        }
        expect(request.url.path, '/schools/school-1/student-fields');
        expect(request.url.queryParameters['include_inactive'], 'true');
        return http.Response('[]', 200);
      }),
    );
    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentFieldsScreen(
          schoolUuid: 'school-1',
          schoolName: 'Greenfield Public School',
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Student Fields'), findsOneWidget);
    expect(find.text('BUILT-IN FIELDS'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Required by CampusID'), findsOneWidget);
    expect(
      tester
          .widget<Switch>(find.byKey(const Key('builtin-enabled-full_name')))
          .onChanged,
      isNull,
    );
    expect(find.text('CUSTOM FIELDS'), findsOneWidget);
    expect(find.text('Add Field'), findsOneWidget);
    expect(
      find.text('No custom student fields have been configured.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabling a built-in field clears required before saving', (
    tester,
  ) async {
    Map<String, dynamic>? saved;
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path == '/schools/school-1/student-field-config') {
          if (request.method == 'PUT') {
            saved = jsonDecode(request.body) as Map<String, dynamic>;
          }
          return http.Response(
            '{"fields":[{"key":"full_name","label":"Full name","data_type":"text","enabled":true,"required":true,"protected":true,"display_order":0},{"key":"aadhaar","label":"Aadhaar","data_type":"text","enabled":true,"required":true,"protected":false,"display_order":1}]}',
            200,
          );
        }
        return http.Response('[]', 200);
      }),
    );
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: StudentFieldsScreen(
          schoolUuid: 'school-1',
          schoolName: 'School',
          api: api,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('builtin-enabled-aadhaar')));
    await tester.pumpAndSettle();
    final fields = saved!['fields'] as List<dynamic>;
    final aadhaar = fields.cast<Map<String, dynamic>>().singleWhere(
      (item) => item['key'] == 'aadhaar',
    );
    expect(aadhaar['enabled'], isFalse);
    expect(aadhaar['required'], isFalse);
  });
}
