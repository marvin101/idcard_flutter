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
    expect(find.text('SYSTEM FIELDS'), findsOneWidget);
    expect(find.text('Student Name'), findsOneWidget);
    expect(find.text('CUSTOM FIELDS'), findsOneWidget);
    expect(find.text('Add Field'), findsOneWidget);
    expect(
      find.text('No custom student fields have been configured.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
