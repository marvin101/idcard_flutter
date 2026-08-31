import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/bulk_photo_import.dart';
import 'package:idcard_flutter/screens/bulk_photo_import_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

class _BulkPhotoApi extends ApiService {
  _BulkPhotoApi({
    required this.preview,
    this.summary,
    this.uploadError,
    this.previewError,
    this.commitError,
  }) : super(baseUrl: 'https://example.test');

  final BulkPhotoPreviewResponse preview;
  final BulkPhotoCommitResponse? summary;
  final Object? uploadError;
  final Object? previewError;
  final Object? commitError;
  int commitCalls = 0;
  bool? confirmed;

  @override
  Future<BulkPhotoUploadResponse> uploadBulkStudentPhotos({
    required String schoolUuid,
    required String filename,
    required Uint8List bytes,
  }) async {
    if (uploadError != null) throw uploadError!;
    return BulkPhotoUploadResponse(
      manifestUuid: 'manifest-1',
      filename: filename,
      totalFiles: preview.totalFiles,
      expiresAt: DateTime.utc(2026, 9, 1),
    );
  }

  @override
  Future<BulkPhotoPreviewResponse> previewBulkStudentPhotos({
    required String schoolUuid,
    required String manifestUuid,
  }) async {
    if (previewError != null) throw previewError!;
    return preview;
  }

  @override
  Future<BulkPhotoCommitResponse> commitBulkStudentPhotos({
    required String schoolUuid,
    required String manifestUuid,
    required bool confirmed,
  }) async {
    commitCalls++;
    this.confirmed = confirmed;
    if (commitError != null) throw commitError!;
    return summary!;
  }
}

const _items = [
  BulkPhotoItem(
    filename: 'A-1.jpg',
    admissionNo: 'A-1',
    studentUuid: 'student-1',
    studentName: 'Asha Singh',
    status: 'ready',
    detail: 'Ready to upload',
    hasExistingPhoto: false,
  ),
  BulkPhotoItem(
    filename: 'UNKNOWN.jpg',
    admissionNo: 'UNKNOWN',
    status: 'unmatched',
    detail: 'No student matches this admission number',
    hasExistingPhoto: false,
  ),
  BulkPhotoItem(
    filename: 'broken.txt',
    status: 'invalid',
    detail: 'Unsupported file type',
    hasExistingPhoto: false,
  ),
  BulkPhotoItem(
    filename: 'B-2.png',
    admissionNo: 'B-2',
    studentUuid: 'student-2',
    studentName: 'Bilal Khan',
    status: 'replacement',
    detail: 'Existing photo will be replaced',
    hasExistingPhoto: true,
  ),
];

BulkPhotoPreviewResponse _preview({bool canCommit = true}) =>
    BulkPhotoPreviewResponse(
      manifestUuid: 'manifest-1',
      totalFiles: 4,
      readyCount: 2,
      unmatchedCount: canCommit ? 0 : 1,
      invalidCount: canCommit ? 0 : 1,
      replacementCount: 1,
      canCommit: canCommit,
      items: _items,
    );

const _summary = BulkPhotoCommitResponse(
  manifestUuid: 'manifest-1',
  totalFiles: 4,
  uploadedCount: 3,
  failedCount: 1,
  unmatchedCount: 0,
  invalidCount: 1,
  replacementCount: 1,
  completed: true,
  items: [
    BulkPhotoCommitItem(
      filename: 'A-1.jpg',
      admissionNo: 'A-1',
      studentUuid: 'student-1',
      studentName: 'Asha Singh',
      status: 'uploaded',
      detail: 'Uploaded',
    ),
  ],
);

void main() {
  test('bulk photo models parse upload, preview, and commit contracts', () {
    final upload = BulkPhotoUploadResponse.fromJson({
      'manifest_uuid': 'manifest-1',
      'filename': 'photos.zip',
      'total_files': 4,
      'expires_at': '2026-09-01T10:30:00Z',
    });
    final preview = BulkPhotoPreviewResponse.fromJson({
      'manifest_uuid': 'manifest-1',
      'total_files': 4,
      'ready_count': 2,
      'unmatched_count': 1,
      'invalid_count': 1,
      'replacement_count': 1,
      'can_commit': false,
      'items': [
        {
          'filename': 'B-2.png',
          'admission_no': 'B-2',
          'student_uuid': 'student-2',
          'student_name': 'Bilal Khan',
          'status': 'replacement',
          'detail': 'Existing photo will be replaced',
          'has_existing_photo': true,
        },
      ],
    });
    final commit = BulkPhotoCommitResponse.fromJson({
      'manifest_uuid': 'manifest-1',
      'total_files': 4,
      'uploaded_count': 3,
      'failed_count': 1,
      'unmatched_count': 0,
      'invalid_count': 1,
      'replacement_count': 1,
      'completed': true,
      'items': [
        {
          'filename': 'A-1.jpg',
          'admission_no': 'A-1',
          'student_uuid': 'student-1',
          'student_name': 'Asha Singh',
          'status': 'uploaded',
          'detail': 'Uploaded',
        },
      ],
    });

    expect(upload.manifestUuid, 'manifest-1');
    expect(upload.expiresAt.isUtc, isTrue);
    expect(preview.items.single.hasExistingPhoto, isTrue);
    expect(preview.canCommit, isFalse);
    expect(commit.uploadedCount, 3);
    expect(commit.completed, isTrue);
    expect(commit.items.single.status, 'uploaded');
  });

  test('upload API uses archive multipart field and expected route', () async {
    late http.Request captured;
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'manifest_uuid': 'manifest-1',
            'filename': 'photos.zip',
            'total_files': 1,
            'expires_at': '2026-09-01T10:30:00Z',
          }),
          200,
        );
      }),
    );

    await api.uploadBulkStudentPhotos(
      schoolUuid: 'school-1',
      filename: 'photos.zip',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    expect(captured.url.path, '/schools/school-1/student-photos/bulk/upload');
    expect(
      captured.headers['content-type'],
      startsWith('multipart/form-data;'),
    );
    expect(captured.body, contains('name="archive"'));
    expect(captured.body, contains('filename="photos.zip"'));
  });

  testWidgets('preview renders all statuses and disables invalid commit', (
    tester,
  ) async {
    final api = _BulkPhotoApi(preview: _preview(canCommit: false));
    await _pumpScreen(tester, api);
    await _chooseArchive(tester);

    expect(find.byKey(const Key('bulk-photo-status-ready')), findsOneWidget);
    expect(
      find.byKey(const Key('bulk-photo-status-unmatched')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('bulk-photo-status-invalid')), findsOneWidget);
    expect(
      find.byKey(const Key('bulk-photo-status-replacement')),
      findsOneWidget,
    );
    expect(find.text('Asha Singh'), findsOneWidget);
    expect(find.text('Existing photo will be replaced'), findsOneWidget);
    final continueButton = tester.widget<FilledButton>(
      find.byKey(const Key('bulk-photo-continue')),
    );
    expect(continueButton.onPressed, isNull);
    expect(
      find.byKey(const Key('bulk-photo-cannot-commit-message')),
      findsOneWidget,
    );
  });

  testWidgets('confirmation is required and commit renders summary counts', (
    tester,
  ) async {
    final api = _BulkPhotoApi(preview: _preview(), summary: _summary);
    await _pumpScreen(tester, api);
    await _chooseArchive(tester);

    await tester.tap(find.byKey(const Key('bulk-photo-continue')));
    await tester.pumpAndSettle();
    var commitButton = tester.widget<FilledButton>(
      find.byKey(const Key('bulk-photo-commit')),
    );
    expect(commitButton.onPressed, isNull);
    expect(api.commitCalls, 0);

    await tester.tap(find.byKey(const Key('bulk-photo-confirmation')));
    await tester.pump();
    commitButton = tester.widget<FilledButton>(
      find.byKey(const Key('bulk-photo-commit')),
    );
    expect(commitButton.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('bulk-photo-commit')));
    await tester.pumpAndSettle();

    expect(api.commitCalls, 1);
    expect(api.confirmed, isTrue);
    expect(find.text('Import completed'), findsOneWidget);
    expect(find.byKey(const Key('bulk-photo-count-uploaded')), findsOneWidget);
    expect(find.byKey(const Key('bulk-photo-count-failed')), findsOneWidget);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('picker exception is rendered and does not leave screen busy', (
    tester,
  ) async {
    final api = _BulkPhotoApi(preview: _preview());
    await _pumpScreen(
      tester,
      api,
      pickArchive: () async => throw StateError('picker failed'),
    );

    await tester.tap(find.byKey(const Key('bulk-photo-choose-archive')));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not open the file picker. Please try again.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('bulk-photo-choose-archive')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('selected ZIP with null bytes renders a readable error', (
    tester,
  ) async {
    final api = _BulkPhotoApi(preview: _preview());
    await _pumpScreen(
      tester,
      api,
      pickArchive: () async => PlatformFile(name: 'photos.zip', size: 10),
    );

    await tester.tap(find.byKey(const Key('bulk-photo-choose-archive')));
    await tester.pumpAndSettle();

    expect(
      find.text('The selected ZIP could not be read. Please choose it again.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('bulk-photo-choose-archive')),
    );
    expect(button.onPressed, isNotNull);
  });

  for (final error in const [
    ApiException(422, 'ZIP contains no supported images'),
    ApiException(410, 'Manifest expired'),
    ApiException(409, 'Manifest already completed'),
  ]) {
    testWidgets('renders backend ${error.statusCode} detail', (tester) async {
      final api = _BulkPhotoApi(
        preview: _preview(),
        uploadError: error.statusCode == 422 ? error : null,
        previewError: error.statusCode == 410 ? error : null,
        commitError: error.statusCode == 409 ? error : null,
        summary: _summary,
      );
      await _pumpScreen(tester, api);
      await _chooseArchive(tester);
      if (error.statusCode == 409) {
        await tester.tap(find.byKey(const Key('bulk-photo-continue')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('bulk-photo-confirmation')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('bulk-photo-commit')));
        await tester.pumpAndSettle();
      }

      expect(find.textContaining(error.message), findsOneWidget);
      expect(find.byKey(const Key('bulk-photo-error')), findsOneWidget);
    });
  }
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _BulkPhotoApi api, {
  BulkPhotoFilePicker? pickArchive,
}) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: BulkPhotoImportScreen(
        schoolUuid: 'school-1',
        schoolName: 'Campus School',
        api: api,
        pickArchive:
            pickArchive ??
            () async => PlatformFile(
              name: 'student-photos.zip',
              size: 3,
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _chooseArchive(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('bulk-photo-choose-archive')));
  await tester.pumpAndSettle();
}
