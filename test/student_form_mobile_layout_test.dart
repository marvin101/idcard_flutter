import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/providers/api_student_form_provider.dart';
import 'package:idcard_flutter/sections/builtin_student_fields_section.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/authenticated_app_bar.dart';
import 'package:provider/provider.dart';

http.Response _builtinConfigResponse() {
  return http.Response(
    jsonEncode({
      'fields': [
        for (final entry in {
          'session_uuid': 'Academic session',
          'class_uuid': 'Class',
          'section_uuid': 'Section',
          'admission_no': 'Admission number',
          'full_name': 'Full name',
          'roll_no': 'Roll number',
          'father_name': 'Father name',
          'mother_name': 'Mother name',
          'dob': 'Date of birth',
          'gender': 'Gender',
          'blood_group': 'Blood group',
          'mobile': 'Mobile',
          'aadhaar': 'Aadhaar',
          'address': 'Address',
        }.entries.toList().asMap().entries)
          {
            'key': entry.value.key,
            'label': entry.value.value,
            'data_type': 'text',
            'enabled': true,
            'required': entry.key < 5,
            'protected': entry.key < 5,
            'display_order': entry.key,
          },
      ],
    }),
    200,
  );
}

ApiService _buildApi() {
  return ApiService(
    baseUrl: 'https://example.test',
    client: MockClient((request) async {
      switch (request.url.path) {
        case '/schools/school-1/academic-sessions':
          return http.Response(
            jsonEncode([
              {
                'uuid': 'session-1',
                'name': '2026-2027',
                'is_current': true,
                'is_active': true,
              },
            ]),
            200,
          );

        case '/schools/school-1/classes':
          return http.Response(
            jsonEncode([
              {'uuid': 'class-1', 'name': '10', 'is_active': true},
            ]),
            200,
          );

        case '/schools/school-1/student-fields':
          return http.Response('[]', 200);

        case '/schools/school-1/student-field-config':
          return _builtinConfigResponse();

        case '/schools/school-1/classes/class-1/sections':
          return http.Response(
            jsonEncode([
              {'uuid': 'section-1', 'name': 'A', 'is_active': true},
            ]),
            200,
          );

        default:
          fail('Unexpected request: ${request.url}');
      }
    }),
  );
}

Future<void> _waitUntilLoaded(ApiStudentFormProvider provider) async {
  if (!provider.loading) {
    return;
  }

  final done = Completer<void>();

  void listener() {
    if (!provider.loading && !done.isCompleted) {
      done.complete();
    }
  }

  provider.addListener(listener);

  await done.future.timeout(const Duration(seconds: 2));

  provider.removeListener(listener);
}

Future<void> _pumpStudentFields(
  WidgetTester tester,
  ApiStudentFormProvider provider, {
  required double width,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Form(
              key: provider.formKey,
              child: const BuiltinStudentFieldsSection(),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pump();
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearAllTestValues();
  });

  testWidgets('360px mobile layout keeps Class and Section on the same row', (
    tester,
  ) async {
    final api = _buildApi();

    final provider = ApiStudentFormProvider(api: api, schoolUuid: 'school-1');

    await _waitUntilLoaded(provider);

    await _pumpStudentFields(tester, provider, width: 360);

    final classPosition = tester.getTopLeft(find.text('Class'));

    final sectionPosition = tester.getTopLeft(find.text('Section'));

    expect((classPosition.dy - sectionPosition.dy).abs(), lessThan(2));

    expect(classPosition.dx, lessThan(sectionPosition.dx));

    expect(tester.takeException(), isNull);

    provider.dispose();
    api.dispose();
  });

  testWidgets('320px mobile layout stacks Class and Section without overflow', (
    tester,
  ) async {
    final api = _buildApi();

    final provider = ApiStudentFormProvider(api: api, schoolUuid: 'school-1');

    await _waitUntilLoaded(provider);

    await _pumpStudentFields(tester, provider, width: 320);

    final classPosition = tester.getTopLeft(find.text('Class'));

    final sectionPosition = tester.getTopLeft(find.text('Section'));

    expect(sectionPosition.dy, greaterThan(classPosition.dy));

    expect(tester.takeException(), isNull);

    provider.dispose();
    api.dispose();
  });

  testWidgets('Section clearly explains that Class must be selected first', (
    tester,
  ) async {
    final api = _buildApi();

    final provider = ApiStudentFormProvider(api: api, schoolUuid: 'school-1');

    await _waitUntilLoaded(provider);

    await _pumpStudentFields(tester, provider, width: 390);

    expect(find.text('Class first'), findsOneWidget);

    expect(tester.takeException(), isNull);

    provider.dispose();
    api.dispose();
  });

  testWidgets('mobile form renders DOB controls without horizontal overflow', (
    tester,
  ) async {
    final api = _buildApi();

    final provider = ApiStudentFormProvider(api: api, schoolUuid: 'school-1');

    await _waitUntilLoaded(provider);

    await _pumpStudentFields(tester, provider, width: 320);

    final dayField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'DD',
    );

    final monthField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'MM',
    );

    final yearField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'YYYY',
    );

    expect(dayField, findsOneWidget);
    expect(monthField, findsOneWidget);
    expect(yearField, findsOneWidget);

    final dayRect = tester.getRect(dayField);
    final monthRect = tester.getRect(monthField);
    final yearRect = tester.getRect(yearField);

    // All DOB controls must stay on one row.
    expect((dayRect.top - monthRect.top).abs(), lessThan(2));

    expect((monthRect.top - yearRect.top).abs(), lessThan(2));

    // Correct DD -> MM -> YYYY order.
    expect(dayRect.left, lessThan(monthRect.left));

    expect(monthRect.left, lessThan(yearRect.left));

    // All three controls must fit inside the 320 px viewport.
    expect(dayRect.left, greaterThanOrEqualTo(0));

    expect(yearRect.right, lessThanOrEqualTo(320));

    expect(tester.takeException(), isNull);

    provider.dispose();
    api.dispose();
  });
  testWidgets('student field controls remain usable at narrow mobile width', (
    tester,
  ) async {
    final api = _buildApi();

    final provider = ApiStudentFormProvider(api: api, schoolUuid: 'school-1');

    await _waitUntilLoaded(provider);

    await _pumpStudentFields(tester, provider, width: 320);

    expect(find.text('Academic session'), findsOneWidget);

    expect(find.text('Admission number'), findsOneWidget);

    expect(find.text('Full name'), findsOneWidget);

    expect(tester.takeException(), isNull);

    provider.dispose();
    api.dispose();
  });

  testWidgets('compact authenticated app bar uses reduced mobile height', (
    tester,
  ) async {
    const compact = AuthenticatedAppBar(
      title: Text('Add student'),
      compact: true,
    );

    const desktop = AuthenticatedAppBar(title: Text('Add student'));

    expect(compact.preferredSize.height, 54);

    expect(desktop.preferredSize.height, 110);
  });
}
