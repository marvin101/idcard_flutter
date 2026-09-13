import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/models/api_personnel.dart';
import 'package:idcard_flutter/models/bulk_photo_import.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_bindings.dart';
import 'package:idcard_flutter/models/personnel_grid.dart';
import 'package:idcard_flutter/screens/personnel_grid_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

Map<String, dynamic> _gridJson() => {
  'rows': [
    {
      'uuid': 'person-1',
      'updated_at': '2026-09-13T10:00:00Z',
      'personnel_type': 'teacher',
      'employee_no': 'EMP-1',
      'full_name': 'Asha Singh',
      'designation': 'Teacher',
      'department': 'Science',
      'dob': null,
      'gender': null,
      'blood_group': null,
      'mobile': null,
      'email': null,
      'address': null,
      'is_active': true,
      'custom_fields': {'field-1': 'Blue'},
    },
  ],
  'total': 1,
  'offset': 0,
  'limit': 100,
  'has_more': false,
  'personnel_type': 'teacher',
  'custom_fields': [
    {
      'uuid': 'field-1',
      'field_key': 'house',
      'label': 'House',
      'data_type': 'text',
      'is_required': false,
      'display_order': 0,
      'is_active': true,
    },
  ],
  'departments': ['Science'],
  'designations': ['Teacher'],
};

void main() {
  test('personnel grid models preserve timestamps, fields and patches', () {
    final page = PersonnelGridPage.fromJson(_gridJson());
    expect(page.rows.single.personnelType, PersonnelType.teacher);
    expect(page.rows.single.systemFields['employee_no'], 'EMP-1');
    expect(page.rows.single.customFields['field-1'], 'Blue');
    expect(page.customFields.single.fieldKey, 'house');

    final patch = PersonnelGridRowPatch(
      personnelUuid: 'person-1',
      expectedUpdatedAt: page.rows.single.updatedAt,
      systemFields: const {'department': 'Mathematics'},
      customFields: const {'field-1': 'Green'},
    ).toJson();
    expect(patch['personnel_uuid'], 'person-1');
    expect(patch['system_fields'], {'department': 'Mathematics'});
  });

  test('personnel grid API sends type, filters and optimistic patch', () async {
    var calls = 0;
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        calls++;
        if (request.method == 'GET') {
          expect(request.url.path, '/schools/school-1/personnel/grid');
          expect(request.url.queryParameters['personnel_type'], 'staff');
          expect(request.url.queryParameters['active'], 'false');
          expect(request.url.queryParameters['department'], 'Office');
          return http.Response(jsonEncode(_gridJson()), 200);
        }
        expect(request.method, 'PATCH');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['rows'][0]['expected_updated_at'], isNotNull);
        return http.Response(
          jsonEncode({'updated_count': 0, 'rows': <dynamic>[]}),
          200,
        );
      }),
    );
    await api.getPersonnelGrid(
      schoolUuid: 'school-1',
      personnelType: PersonnelType.staff,
      active: false,
      department: 'Office',
    );
    await api.patchPersonnelGrid(
      schoolUuid: 'school-1',
      rows: [
        PersonnelGridRowPatch(
          personnelUuid: 'person-1',
          expectedUpdatedAt: DateTime.utc(2026, 9, 13),
          systemFields: const {'full_name': 'Mira'},
          customFields: const {},
        ),
      ],
    );
    expect(calls, 2);
  });

  test(
    'personnel import preview and commit use type-scoped endpoints',
    () async {
      final paths = <String>[];
      final api = ApiService(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          paths.add(request.url.path);
          expect(request.url.queryParameters['personnel_type'], 'teacher');
          if (request.url.path.endsWith('/preview')) {
            return http.Response(
              jsonEncode({
                'upload_id': 'upload-1',
                'personnel_type': 'teacher',
                'total_rows': 1,
                'valid_rows': 1,
                'invalid_rows': 0,
                'duplicate_rows': 0,
                'can_import': true,
                'rows': <dynamic>[],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'upload_id': 'upload-1',
              'personnel_type': 'teacher',
              'imported_count': 1,
              'skipped_count': 0,
              'message': 'Imported 1 teacher',
            }),
            201,
          );
        }),
      );
      await api.previewPersonnelImport(
        schoolUuid: 'school-1',
        personnelType: PersonnelType.teacher,
        uploadId: 'upload-1',
        mappings: const [],
      );
      await api.commitPersonnelImport(
        schoolUuid: 'school-1',
        personnelType: PersonnelType.teacher,
        uploadId: 'upload-1',
        mappings: const [],
        confirmed: true,
      );
      expect(paths, [
        '/schools/school-1/personnel/imports/upload-1/preview',
        '/schools/school-1/personnel/imports/upload-1/commit',
      ]);
    },
  );

  test('bulk photo models accept personnel response aliases', () {
    final preview = BulkPhotoPreviewResponse.fromJson({
      'manifest_uuid': 'manifest-1',
      'total_files': 1,
      'ready_count': 1,
      'unmatched_count': 0,
      'invalid_count': 0,
      'replacement_count': 0,
      'can_commit': true,
      'items': [
        {
          'filename': 'EMP-1.png',
          'employee_no': 'EMP-1',
          'personnel_uuid': 'person-1',
          'personnel_name': 'Asha Singh',
          'status': 'ready',
          'has_existing_photo': false,
        },
      ],
    });
    expect(preview.items.single.admissionNo, 'EMP-1');
    expect(preview.items.single.studentUuid, 'person-1');
    expect(preview.items.single.studentName, 'Asha Singh');
  });

  test('personnel bulk photo preview and commit stay type scoped', () async {
    final paths = <String>[];
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.url.queryParameters['personnel_type'], 'staff');
        if (request.url.path.endsWith('/preview')) {
          return http.Response(
            jsonEncode({
              'manifest_uuid': 'manifest-1',
              'personnel_type': 'staff',
              'total_files': 1,
              'ready_count': 1,
              'unmatched_count': 0,
              'invalid_count': 0,
              'replacement_count': 0,
              'can_commit': true,
              'items': <dynamic>[],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'manifest_uuid': 'manifest-1',
            'personnel_type': 'staff',
            'total_files': 1,
            'uploaded_count': 1,
            'failed_count': 0,
            'unmatched_count': 0,
            'invalid_count': 0,
            'replacement_count': 0,
            'completed': true,
            'items': <dynamic>[],
          }),
          200,
        );
      }),
    );
    await api.previewBulkPersonnelPhotos(
      schoolUuid: 'school-1',
      personnelType: PersonnelType.staff,
      manifestUuid: 'manifest-1',
    );
    await api.commitBulkPersonnelPhotos(
      schoolUuid: 'school-1',
      personnelType: PersonnelType.staff,
      manifestUuid: 'manifest-1',
      confirmed: true,
    );
    expect(paths, [
      '/schools/school-1/personnel-photos/bulk/manifest-1/preview',
      '/schools/school-1/personnel-photos/bulk/manifest-1/commit',
    ]);
  });

  test('personnel binding suppresses student-only single and multi fields', () {
    final personnel = ApiPersonnel.fromJson({
      'uuid': 'person-1',
      'personnel_type': 'staff',
      'employee_no': 'EMP-1',
      'full_name': 'Mira Das',
      'is_active': true,
      'created_at': '2026-09-13T00:00:00Z',
      'updated_at': '2026-09-13T00:00:00Z',
    });
    final bindings = DesignBindings(personnel: personnel);
    const studentText = DesignElement(
      id: 'student-only',
      type: DesignElementType.boundText,
      x: 0,
      y: 0,
      width: 20,
      height: 5,
      data: {'field': 'admission_no', 'fallback': 'Admission number'},
    );
    const multi = DesignElement(
      id: 'multi',
      type: DesignElementType.qrCode,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      data: {
        'fields': [
          {'field': 'full_name', 'label': 'Name'},
          {'field': 'roll_no', 'label': 'Roll'},
          {'field': 'employee_no', 'label': 'Employee'},
        ],
        'format': 'json',
      },
    );
    expect(bindings.text(studentText), isEmpty);
    expect(
      bindings.text(multi),
      '{"full_name":"Mira Das","employee_no":"EMP-1"}',
    );
  });

  test('new personnel workflow routes are protected', () {
    expect(AppRoutes.isProtected(AppRoutes.teacherImport), isTrue);
    expect(AppRoutes.isProtected(AppRoutes.staffBulkPhotoImport), isTrue);
    expect(AppRoutes.isProtected(AppRoutes.teacherGrid), isTrue);
  });

  testWidgets('personnel grid loads fields, edits and saves a dirty row', (
    tester,
  ) async {
    final api = _GridApi();
    await tester.pumpWidget(
      MaterialApp(
        home: PersonnelGridScreen(
          schoolUuid: 'school-1',
          schoolName: 'Campus School',
          api: api,
          initialType: PersonnelType.teacher,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Employee No.'), findsOneWidget);
    expect(find.text('House'), findsOneWidget);
    final name = find.byKey(const ValueKey('person-1-full_name-1'));
    expect(name, findsOneWidget);
    tester.widget<TextFormField>(name).onChanged!('Asha Sharma');
    await tester.pump();
    final save = find.byKey(const Key('personnel-grid-save'));
    final button = tester.widget<FilledButton>(save);
    expect(button.onPressed, isNotNull);
    button.onPressed!();
    await tester.pumpAndSettle();
    expect(api.saved.single.systemFields['full_name'], 'Asha Sharma');
  });
}

class _GridApi extends ApiService {
  final saved = <PersonnelGridRowPatch>[];

  @override
  Future<PersonnelGridPage> getPersonnelGrid({
    required String schoolUuid,
    required PersonnelType personnelType,
    int limit = 100,
    int offset = 0,
    String? search,
    bool? active = true,
    String? department,
    String? designation,
  }) async => PersonnelGridPage.fromJson(_gridJson());

  @override
  Future<PersonnelGridPatchResult> patchPersonnelGrid({
    required String schoolUuid,
    required List<PersonnelGridRowPatch> rows,
  }) async {
    saved.addAll(rows);
    return const PersonnelGridPatchResult(updatedCount: 1, rows: []);
  }
}
