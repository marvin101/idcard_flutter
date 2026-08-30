import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/student_field.dart';
import 'package:idcard_flutter/providers/api_student_form_provider.dart';
import 'package:idcard_flutter/screens/student_fields_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/sections/custom_student_fields_section.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _studentJson({List<dynamic> customFields = const []}) => {
  'uuid': 'student-1',
  'session_uuid': 'session-1',
  'class_uuid': 'class-1',
  'section_uuid': 'section-1',
  'admission_no': 'A-1',
  'roll_no': null,
  'stream': null,
  'full_name': 'Student One',
  'father_name': null,
  'mother_name': null,
  'dob': null,
  'gender': null,
  'blood_group': null,
  'mobile': null,
  'aadhaar': null,
  'address': null,
  'photo_path': null,
  'is_active': true,
  'custom_fields': customFields,
};

Future<void> _waitUntilLoaded(ApiStudentFormProvider provider) async {
  if (!provider.loading) return;
  final done = Completer<void>();
  void listener() {
    if (!provider.loading && !done.isCompleted) done.complete();
  }
  provider.addListener(listener);
  await done.future.timeout(const Duration(seconds: 2));
  provider.removeListener(listener);
}

void main() {
  test('field management is visible only to platform and school admins', () {
    expect(
      canManageStudentFields(isPlatformAdmin: true, schoolRole: null),
      isTrue,
    );
    expect(
      canManageStudentFields(isPlatformAdmin: false, schoolRole: 'school_admin'),
      isTrue,
    );
    for (final role in ['card_operator', 'teacher', 'staff']) {
      expect(
        canManageStudentFields(isPlatformAdmin: false, schoolRole: role),
        isFalse,
      );
    }
  });

  test('student model restores returned custom field values', () {
    final student = ApiStudent.fromJson(
      _studentJson(customFields: [
        {
          'field_uuid': 'field-1',
          'field_key': 'house',
          'label': 'House',
          'data_type': 'text',
          'value': 'Blue',
          'is_active': true,
        },
      ]),
    );
    expect(student.customFields.single.fieldUuid, 'field-1');
    expect(student.customFields.single.value, 'Blue');
  });

  test('update serializes custom field values without changing legacy fields', () async {
    late Map<String, dynamic> body;
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_studentJson()), 200);
      }),
    );
    await api.updateStudent(
      schoolUuid: 'school-1',
      studentUuid: 'student-1',
      sessionUuid: 'session-1',
      classUuid: 'class-1',
      sectionUuid: 'section-1',
      admissionNo: 'A-1',
      fullName: 'Student One',
      customFields: const [
        StudentCustomFieldValue(fieldUuid: 'field-1', value: 'Blue'),
      ],
    );
    expect(body['full_name'], 'Student One');
    expect(body['custom_fields'], [
      {'field_uuid': 'field-1', 'value': 'Blue'},
    ]);
    api.dispose();
  });

  test('zero custom fields preserves the existing form state', () async {
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/schools/school-1/academic-sessions':
          case '/schools/school-1/classes':
          case '/schools/school-1/student-fields':
            return http.Response('[]', 200);
          default:
            fail('Unexpected request: ${request.url}');
        }
      }),
    );
    final provider = ApiStudentFormProvider(api: api, schoolUuid: 'school-1');
    await _waitUntilLoaded(provider);
    expect(provider.error, isNull);
    expect(provider.customFields, isEmpty);
    expect(provider.serializedCustomFields, isEmpty);
    provider.dispose();
    api.dispose();
  });

  test('edit form controllers restore saved active custom values', () async {
    final student = ApiStudent.fromJson(
      _studentJson(customFields: [
        {
          'field_uuid': 'field-1',
          'field_key': 'house',
          'label': 'House',
          'data_type': 'text',
          'value': 'Blue',
          'is_active': true,
        },
      ]),
    );
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/schools/school-1/academic-sessions':
            return http.Response(
              jsonEncode([
                {'uuid': 'session-1', 'name': '2026', 'is_current': true, 'is_active': true},
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
            return http.Response(
              jsonEncode([
                {
                  'uuid': 'field-1',
                  'field_key': 'house',
                  'label': 'House',
                  'data_type': 'text',
                  'is_required': true,
                  'display_order': 0,
                  'is_active': true,
                },
              ]),
              200,
            );
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
    final provider = ApiStudentFormProvider(
      api: api,
      schoolUuid: 'school-1',
      student: student,
    );
    await _waitUntilLoaded(provider);
    expect(provider.error, isNull);
    expect(provider.customFieldControllers['field-1']?.text, 'Blue');
    expect(provider.serializedCustomFields.single.value, 'Blue');
    provider.dispose();
    api.dispose();
  });

  testWidgets('custom fields render and required validation is enforced', (
    tester,
  ) async {
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.url.path == '/schools/school-1/student-fields') {
          return http.Response(
            jsonEncode([
              {
                'uuid': 'field-1',
                'field_key': 'house',
                'label': 'House',
                'data_type': 'text',
                'is_required': true,
                'display_order': 0,
                'is_active': true,
              },
            ]),
            200,
          );
        }
        if (request.url.path == '/schools/school-1/academic-sessions' ||
            request.url.path == '/schools/school-1/classes') {
          return http.Response('[]', 200);
        }
        fail('Unexpected request: ${request.url}');
      }),
    );
    final formKey = GlobalKey<FormState>();
    final provider = ApiStudentFormProvider(api: api, schoolUuid: 'school-1');
    await _waitUntilLoaded(provider);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: const CustomStudentFieldsSection(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('House'), findsOneWidget);
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('House is required.'), findsOneWidget);

    provider.dispose();
    api.dispose();
  });
}
