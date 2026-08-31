import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/student_import.dart';
import 'package:idcard_flutter/screens/student_import_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

class _StudentImportApi extends ApiService {
  _StudentImportApi() : super(baseUrl: 'https://example.test');

  String? templateSchoolUuid;
  Object? templateError;

  @override
  Future<StudentImportTemplateFile> downloadStudentImportTemplate({
    required String schoolUuid,
  }) async {
    templateSchoolUuid = schoolUuid;
    if (templateError != null) throw templateError!;
    return StudentImportTemplateFile(
      bytes: Uint8List.fromList([80, 75, 3, 4]),
      filename: 'student_import_template_campus_school.xlsx',
      contentType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  @override
  Future<StudentImportUpload> uploadStudentImport({
    required String schoolUuid,
    required String filename,
    required Uint8List bytes,
  }) async => const StudentImportUpload(
    uploadId: 'upload-1',
    filename: 'students.csv',
    headers: ['Name'],
    rowCount: 1,
    targetFields: [
      StudentImportTargetField(
        key: 'full_name',
        label: 'Full Name',
        required: true,
        dataType: 'text',
      ),
    ],
    suggestedMappings: [
      StudentImportMapping(sourceColumn: 'Name', targetField: 'full_name'),
    ],
  );

  @override
  Future<StudentImportPreview> previewStudentImport({
    required String schoolUuid,
    required String uploadId,
    required List<StudentImportMapping> mappings,
  }) async => const StudentImportPreview(
    totalRows: 1,
    validRows: 1,
    invalidRows: 0,
    duplicateRows: 0,
    canImport: true,
    rows: [],
  );

  @override
  Future<StudentImportSummary> commitStudentImport({
    required String schoolUuid,
    required String uploadId,
    required List<StudentImportMapping> mappings,
    required bool confirmed,
  }) async => const StudentImportSummary(
    importedCount: 1,
    skippedCount: 0,
    message: 'Import complete',
  );
}

void main() {
  test('import upload and preview models parse backend contracts', () {
    final upload = StudentImportUpload.fromJson({
      'upload_id': 'upload-1',
      'filename': 'students.csv',
      'headers': ['Name'],
      'row_count': 2,
      'target_fields': [
        {
          'key': 'full_name',
          'label': 'Full Name',
          'required': true,
          'data_type': 'text',
        },
      ],
      'suggested_mappings': [
        {'source_column': 'Name', 'target_field': 'full_name'},
      ],
    });
    final preview = StudentImportPreview.fromJson({
      'total_rows': 2,
      'valid_rows': 1,
      'invalid_rows': 1,
      'duplicate_rows': 1,
      'can_import': false,
      'rows': [
        {
          'row_number': 3,
          'values': {'full_name': 'Asha'},
          'errors': ['Duplicate admission number within upload'],
        },
      ],
    });

    expect(upload.suggestedMappings.single.targetField, 'full_name');
    expect(upload.targetFields.single.required, isTrue);
    expect(preview.canImport, isFalse);
    expect(preview.rows.single.rowNumber, 3);
  });

  test('preview API sends the list-based mapping contract', () async {
    late http.Request captured;
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'upload_id': 'upload-1',
            'total_rows': 1,
            'valid_rows': 1,
            'invalid_rows': 0,
            'duplicate_rows': 0,
            'can_import': true,
            'rows': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final preview = await api.previewStudentImport(
      schoolUuid: 'school-1',
      uploadId: 'upload-1',
      mappings: const [
        StudentImportMapping(sourceColumn: 'Name', targetField: 'full_name'),
      ],
    );

    expect(
      captured.url.path,
      '/schools/school-1/students/imports/upload-1/preview',
    );
    expect(jsonDecode(captured.body), {
      'mappings': [
        {'source_column': 'Name', 'target_field': 'full_name'},
      ],
    });
    expect(preview.canImport, isTrue);
  });

  test('template API returns bytes and response metadata', () async {
    late http.Request captured;
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        captured = request;
        return http.Response.bytes(
          [80, 75, 3, 4],
          200,
          headers: {
            'content-type':
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'content-disposition':
                'attachment; filename="student_import_template_campus.xlsx"',
          },
        );
      }),
    );

    final file = await api.downloadStudentImportTemplate(
      schoolUuid: 'school-1',
    );

    expect(captured.url.path, '/schools/school-1/students/imports/template');
    expect(file.filename, 'student_import_template_campus.xlsx');
    expect(file.bytes, [80, 75, 3, 4]);
  });

  testWidgets('bulk import screen exposes the five-stage flow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentImportScreen(
          schoolUuid: 'school-1',
          schoolName: 'Campus School',
          api: ApiService(baseUrl: 'https://example.test'),
        ),
      ),
    );

    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    expect(find.text('Summary'), findsOneWidget);
    expect(find.text('Choose file'), findsOneWidget);
    expect(find.text('Download XLSX Template'), findsOneWidget);
  });

  testWidgets(
    'template action downloads for the selected school without navigation',
    (tester) async {
      final api = _StudentImportApi();
      StudentImportTemplateFile? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: StudentImportScreen(
            schoolUuid: 'school-1',
            schoolName: 'Campus School',
            api: api,
            saveTemplate: (file) async => saved = file,
          ),
        ),
      );

      await tester.tap(find.text('Download XLSX Template'));
      await tester.pumpAndSettle();

      expect(api.templateSchoolUuid, 'school-1');
      expect(saved?.filename, 'student_import_template_campus_school.xlsx');
      expect(find.byType(StudentImportScreen), findsOneWidget);
      expect(find.text('XLSX template downloaded.'), findsOneWidget);
    },
  );

  testWidgets('template API failure renders a user-facing error', (
    tester,
  ) async {
    final api = _StudentImportApi()
      ..templateError = const ApiException(
        403,
        'Template download is not permitted.',
      );
    await tester.pumpWidget(
      MaterialApp(
        home: StudentImportScreen(
          schoolUuid: 'school-1',
          schoolName: 'Campus School',
          api: api,
          saveTemplate: (_) async {},
        ),
      ),
    );

    await tester.tap(find.text('Download XLSX Template'));
    await tester.pumpAndSettle();

    expect(find.text('Template download is not permitted.'), findsOneWidget);
    expect(find.text('Download XLSX Template'), findsOneWidget);
  });

  testWidgets('picker exception is rendered and does not leave screen busy', (
    tester,
  ) async {
    await _pumpImportScreen(
      tester,
      pickFile: () async => throw StateError('picker failed'),
    );

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not open the file picker. Please try again.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Choose file'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('selected file with null bytes renders a readable error', (
    tester,
  ) async {
    await _pumpImportScreen(
      tester,
      pickFile: () async => PlatformFile(name: 'students.csv', size: 10),
    );

    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();

    expect(find.text('The selected file could not be read.'), findsOneWidget);
    expect(find.text('Choose file'), findsOneWidget);
  });

  testWidgets('summary returns to students through centralized navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/import'),
              child: const Text('Open import'),
            ),
          ),
        ),
        routes: {
          '/import': (_) => StudentImportScreen(
            schoolUuid: 'school-1',
            schoolName: 'Campus School',
            api: _StudentImportApi(),
            pickFile: () async => PlatformFile(
              name: 'students.csv',
              size: 3,
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ),
        },
      ),
    );

    await tester.tap(find.text('Open import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview import'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue to confirmation'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Import students'));
    await tester.pumpAndSettle();
    final returnButton = find.byKey(
      const Key('student-import-return-to-students'),
    );
    await tester.ensureVisible(returnButton);
    await tester.tap(returnButton);
    await tester.pumpAndSettle();

    expect(find.text('Open import'), findsOneWidget);
    expect(find.byType(StudentImportScreen), findsNothing);
  });
}

Future<void> _pumpImportScreen(
  WidgetTester tester, {
  required StudentImportFilePicker pickFile,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: StudentImportScreen(
        schoolUuid: 'school-1',
        schoolName: 'Campus School',
        api: ApiService(baseUrl: 'https://example.test'),
        pickFile: pickFile,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
