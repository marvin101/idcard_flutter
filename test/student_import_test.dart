import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/student_import.dart';
import 'package:idcard_flutter/screens/student_import_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

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
  });
}
