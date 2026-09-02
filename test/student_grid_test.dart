import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/models/academic_session.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/school_class.dart';
import 'package:idcard_flutter/models/student_field.dart';
import 'package:idcard_flutter/models/student_grid.dart';
import 'package:idcard_flutter/screens/student_grid_screen.dart';
import 'package:idcard_flutter/screens/student_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

const _session = StudentGridLookupItem(uuid: 'session-1', name: '2026-27');
const _class = StudentGridLookupItem(uuid: 'class-1', name: '10');
const _otherClass = StudentGridLookupItem(uuid: 'class-2', name: '11');
const _section = StudentGridLookupItem(
  uuid: 'section-1',
  name: 'A',
  classUuid: 'class-1',
);
const _otherSection = StudentGridLookupItem(
  uuid: 'section-2',
  name: 'B',
  classUuid: 'class-2',
);

StudentGridRow _row(String uuid, String admission, String name) =>
    StudentGridRow(
      uuid: uuid,
      updatedAt: DateTime.utc(2026, 9, 2, 10),
      values: {
        'session_uuid': 'session-1',
        'class_uuid': 'class-1',
        'section_uuid': 'section-1',
        'admission_no': admission,
        'roll_no': admission.substring(2),
        'stream': null,
        'full_name': name,
        'father_name': null,
        'mother_name': null,
        'dob': '2010-01-02',
        'gender': 'Female',
        'blood_group': 'A+',
        'mobile': '9876543210',
        'aadhaar': null,
        'address': null,
      },
      customFields: const {
        'field-text': 'Blue',
        'field-number': '12.5',
        'field-date': '2026-01-01',
        'field-phone': '+91 98765 43210',
        'field-multiline': 'Line one',
      },
    );

StudentGridPage _page() => StudentGridPage(
  rows: [_row('student-1', 'A-1', 'Asha'), _row('student-2', 'A-2', 'Bina')],
  total: 2,
  offset: 0,
  limit: 100,
  hasMore: false,
  customFields: const [
    StudentFieldDefinition(
      uuid: 'field-text',
      fieldKey: 'house',
      label: 'House',
      dataType: 'text',
      isRequired: true,
      displayOrder: 0,
      isActive: true,
    ),
    StudentFieldDefinition(
      uuid: 'field-number',
      fieldKey: 'height',
      label: 'Height',
      dataType: 'number',
      isRequired: false,
      displayOrder: 1,
      isActive: true,
    ),
    StudentFieldDefinition(
      uuid: 'field-date',
      fieldKey: 'joined',
      label: 'Joined',
      dataType: 'date',
      isRequired: false,
      displayOrder: 2,
      isActive: true,
    ),
    StudentFieldDefinition(
      uuid: 'field-phone',
      fieldKey: 'guardian_phone',
      label: 'Guardian Phone',
      dataType: 'phone',
      isRequired: false,
      displayOrder: 3,
      isActive: true,
    ),
    StudentFieldDefinition(
      uuid: 'field-multiline',
      fieldKey: 'notes',
      label: 'Notes',
      dataType: 'multiline',
      isRequired: false,
      displayOrder: 4,
      isActive: true,
    ),
  ],
  sessions: const [_session],
  classes: const [_class, _otherClass],
  sections: const [_section, _otherSection],
);

class _GridApi extends ApiService {
  _GridApi() : super(baseUrl: 'https://example.test');

  StudentGridPage page = _page();
  List<StudentGridRowPatch>? savedRows;
  ApiException? saveError;
  int loads = 0;
  String? search;
  String? sessionUuid;
  String? classUuid;
  String? sectionUuid;

  @override
  Future<List<AcademicSession>> getAcademicSessions(String schoolUuid) async =>
      const [];

  @override
  Future<List<SchoolClass>> getClasses(String schoolUuid) async => const [];

  @override
  Future<List<ApiStudent>> getStudents({
    required String schoolUuid,
    String? admissionNo,
    String? sessionUuid,
    String? classUuid,
    String? sectionUuid,
    String? verificationStatus,
    bool? printed,
  }) async => const [];

  @override
  Future<StudentGridPage> getStudentGrid({
    required String schoolUuid,
    int limit = 100,
    int offset = 0,
    String? search,
    String? sessionUuid,
    String? classUuid,
    String? sectionUuid,
  }) async {
    loads++;
    this.search = search;
    this.sessionUuid = sessionUuid;
    this.classUuid = classUuid;
    this.sectionUuid = sectionUuid;
    return page;
  }

  @override
  Future<StudentGridPatchResult> patchStudentGrid({
    required String schoolUuid,
    required List<StudentGridRowPatch> rows,
  }) async {
    savedRows = rows;
    if (saveError case final error?) throw error;
    return StudentGridPatchResult(updatedCount: rows.length, rows: page.rows);
  }
}

Finder _cell(String row, String field) =>
    find.byKey(Key('student-grid-cell-$row-$field'));

Finder _textCell(String row, String field) => find.descendant(
  of: _cell(row, field),
  matching: find.byType(TextFormField),
);

Future<_GridApi> _pumpGrid(WidgetTester tester, {_GridApi? api}) async {
  tester.view.physicalSize = const Size(1800, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final resolved = api ?? _GridApi();
  await tester.pumpWidget(
    MaterialApp(
      home: StudentGridScreen(
        schoolUuid: 'school-1',
        schoolName: 'Campus School',
        api: resolved,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return resolved;
}

void main() {
  test('grid API parses metadata and sends only supplied patches', () async {
    late http.Request request;
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((incoming) async {
        request = incoming;
        if (incoming.method == 'GET') {
          return http.Response(
            jsonEncode({
              'rows': [],
              'total': 0,
              'offset': 0,
              'limit': 50,
              'has_more': false,
              'custom_fields': [],
              'sessions': [],
              'classes': [],
              'sections': [],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'updated_count': 1, 'rows': []}), 200);
      }),
    );
    final page = await api.getStudentGrid(
      schoolUuid: 'school-1',
      limit: 50,
      search: 'Asha',
    );
    expect(page.limit, 50);
    expect(request.url.path, '/schools/school-1/students/grid');
    expect(request.url.queryParameters['search'], 'Asha');
    await api.patchStudentGrid(
      schoolUuid: 'school-1',
      rows: [
        StudentGridRowPatch(
          studentUuid: 'student-1',
          expectedUpdatedAt: DateTime.utc(2026, 9, 2),
          systemFields: const {'full_name': 'Updated'},
          customFields: const {},
        ),
      ],
    );
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    expect((body['rows'] as List).single['system_fields'], {
      'full_name': 'Updated',
    });
    expect((body['rows'] as List).single['expected_updated_at'], isNotNull);
  });

  test('structured backend errors are retained by ApiException', () async {
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'detail': 'Grid validation failed',
            'errors': [
              {
                'student_uuid': 'student-1',
                'field': 'admission_no',
                'message': 'Admission number already exists',
              },
            ],
          }),
          422,
        ),
      ),
    );
    await expectLater(
      api.patchStudentGrid(schoolUuid: 'school-1', rows: const []),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.message,
              'message',
              'Grid validation failed',
            )
            .having(
              (error) => error.gridErrors.single.field,
              'field',
              'admission_no',
            ),
      ),
    );
  });

  testWidgets('grid loads rows, custom columns, and starts clean', (
    tester,
  ) async {
    await _pumpGrid(tester);
    expect(find.text('Admission No. *'), findsOneWidget);
    expect(find.text('House *'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('All changes saved'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('student-grid-save')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets(
    'editing sends only changed fields and success clears dirty state',
    (tester) async {
      final api = await _pumpGrid(tester);
      await tester.enterText(
        _textCell('student-1', 'full_name'),
        'Asha Updated',
      );
      await tester.pump();
      expect(find.text('1 unsaved row(s)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('student-grid-save')));
      await tester.pumpAndSettle();
      expect(api.savedRows, hasLength(1));
      expect(api.savedRows!.single.systemFields, {'full_name': 'Asha Updated'});
      expect(api.savedRows!.single.customFields, isEmpty);
      expect(find.text('All changes saved'), findsOneWidget);
    },
  );

  testWidgets('blood group is a dropdown and class change resets section', (
    tester,
  ) async {
    await _pumpGrid(tester);
    final blood = find.descendant(
      of: _cell('student-1', 'blood_group'),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.ensureVisible(blood);
    await tester.tap(blood);
    await tester.pumpAndSettle();
    await tester.tap(find.text('B+').last);
    await tester.pumpAndSettle();

    final classField = find.descendant(
      of: _cell('student-1', 'class_uuid'),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tester.ensureVisible(classField);
    await tester.tap(classField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('11').last);
    await tester.pumpAndSettle();
    expect(find.text('Section is required'), findsOneWidget);
  });

  testWidgets('custom typed fields validate immediately', (tester) async {
    await _pumpGrid(tester);
    await tester.enterText(
      _textCell('student-1', 'custom:field-number'),
      'twelve',
    );
    await tester.pump();
    expect(find.text('Height must be a number'), findsOneWidget);
    await tester.enterText(
      _textCell('student-1', 'custom:field-date'),
      '02/09/2026',
    );
    await tester.pump();
    expect(find.text('Joined must use YYYY-MM-DD'), findsOneWidget);
    await tester.enterText(_textCell('student-1', 'custom:field-phone'), '12x');
    await tester.pump();
    expect(
      find.text('Guardian Phone must be a valid phone number'),
      findsOneWidget,
    );
  });

  testWidgets('custom edits are sent separately from system fields', (
    tester,
  ) async {
    final api = await _pumpGrid(tester);
    await tester.enterText(
      _textCell('student-1', 'custom:field-text'),
      'Green',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('student-grid-save')));
    await tester.pumpAndSettle();
    expect(api.savedRows!.single.systemFields, isEmpty);
    expect(api.savedRows!.single.customFields, {'field-text': 'Green'});
  });

  testWidgets('backend validation keeps edits and marks the failing cell', (
    tester,
  ) async {
    final api = _GridApi()
      ..saveError = const ApiException(422, 'Grid validation failed', [
        StudentGridCellError(
          studentUuid: 'student-1',
          field: 'admission_no',
          message: 'Admission number already exists',
        ),
      ]);
    await _pumpGrid(tester, api: api);
    await tester.enterText(_textCell('student-1', 'admission_no'), 'A-2');
    await tester.pump();
    await tester.tap(find.byKey(const Key('student-grid-save')));
    await tester.pumpAndSettle();
    expect(api.savedRows, hasLength(1));
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: _textCell('student-1', 'admission_no'),
              matching: find.byType(TextField),
            ),
          )
          .decoration
          ?.errorText,
      'Admission number already exists',
    );
    expect(find.text('1 unsaved row(s)'), findsOneWidget);
  });

  testWidgets('discard restores loaded values', (tester) async {
    await _pumpGrid(tester);
    await tester.enterText(_textCell('student-1', 'full_name'), 'Temporary');
    await tester.pump();
    await tester.tap(find.byKey(const Key('student-grid-discard')));
    await tester.pump();
    final field = tester.widget<EditableText>(
      find.descendant(
        of: _textCell('student-1', 'full_name'),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, 'Asha');
    expect(find.text('All changes saved'), findsOneWidget);
  });

  testWidgets('refresh warns before discarding unsaved changes', (
    tester,
  ) async {
    final api = await _pumpGrid(tester);
    await tester.enterText(_textCell('student-1', 'full_name'), 'Temporary');
    await tester.pump();
    await tester.tap(find.byKey(const Key('student-grid-refresh')));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(api.loads, 1);
    expect(find.text('1 unsaved row(s)'), findsOneWidget);
  });

  testWidgets('search and filters reload bounded server data', (tester) async {
    final api = await _pumpGrid(tester);
    await tester.enterText(
      find.byKey(const Key('student-grid-search')),
      'Bina',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(api.search, 'Bina');
    expect(api.loads, greaterThan(1));

    final sessionFilter = find.byKey(const Key('student-grid-filter-session'));
    await tester.tap(sessionFilter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026-27').last);
    await tester.pumpAndSettle();
    expect(api.sessionUuid, 'session-1');
  });

  testWidgets('Enter moves focus down the same column and Escape reverts', (
    tester,
  ) async {
    await _pumpGrid(tester);
    final first = _textCell('student-1', 'full_name');
    final second = _textCell('student-2', 'full_name');
    await tester.tap(first);
    await tester.enterText(first, 'Changed');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: second, matching: find.byType(EditableText)),
          )
          .focusNode
          .hasFocus,
      isTrue,
    );
    await tester.tap(first);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(tester.widget<TextFormField>(first).initialValue, 'Asha');
  });

  testWidgets('Students exposes grid only when card editing is allowed', (
    tester,
  ) async {
    final api = _GridApi();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentsScreen(
          schoolUuid: 'school-1',
          schoolName: 'School',
          api: api,
          canEdit: false,
          canDelete: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-grid-action')), findsNothing);
    expect(AppRoutes.isProtected(AppRoutes.studentGrid), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: StudentsScreen(
          schoolUuid: 'school-1',
          schoolName: 'School',
          api: api,
          canEdit: true,
          canDelete: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-grid-action')), findsOneWidget);
  });
}
