import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/academic_session.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/bulk_card_export.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/school_class.dart';
import 'package:idcard_flutter/models/school_profile.dart';
import 'package:idcard_flutter/models/section.dart';
import 'package:idcard_flutter/screens/cards_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/services/pdf_service.dart';

ApiStudent student(
  int index, {
  String? name,
  String admissionNo = 'ADM',
  String? photoPath,
}) => ApiStudent(
  uuid: 'student-$index',
  sessionUuid: 'session',
  classUuid: 'class',
  sectionUuid: 'section',
  admissionNo: '$admissionNo-$index',
  rollNo: '${index + 1}',
  fullName: name ?? 'Student $index',
  photoPath: photoPath,
  isActive: true,
);

final bulkTemplate = CardTemplate(
  name: 'Bulk template',
  document: const DesignDocument(
    canvas: DesignCanvas(width: 85.6, height: 53.98),
    elements: [
      DesignElement(
        id: 'name',
        type: DesignElementType.boundText,
        x: 4,
        y: 4,
        width: 50,
        height: 8,
        data: {'field': 'full_name'},
      ),
      DesignElement(
        id: 'admission',
        type: DesignElementType.boundText,
        x: 4,
        y: 14,
        width: 50,
        height: 8,
        data: {'field': 'admission_no'},
      ),
      DesignElement(
        id: 'photo',
        type: DesignElementType.studentPhoto,
        x: 60,
        y: 4,
        width: 18,
        height: 22,
      ),
    ],
  ),
);

class BulkApi extends ApiService {
  BulkApi(this.students) : super(baseUrl: 'https://example.test');

  final List<ApiStudent> students;
  final List<Map<String, Object?>> pageRequests = [];

  @override
  Future<List<AcademicSession>> getAcademicSessions(String schoolUuid) async =>
      const [
        AcademicSession(uuid: 'session', name: '2026–27', isCurrent: true),
      ];

  @override
  Future<List<SchoolClass>> getClasses(String schoolUuid) async => const [
    SchoolClass(uuid: 'class', name: '10'),
  ];

  @override
  Future<List<SchoolSection>> getSections({
    required String schoolUuid,
    required String classUuid,
  }) async => const [SchoolSection(uuid: 'section', name: 'A')];

  @override
  Future<CardTemplate> getCardTemplate(String schoolUuid) async => bulkTemplate;

  @override
  Future<ApiStudent> getStudent({
    required String schoolUuid,
    required String studentUuid,
  }) async => students.firstWhere((student) => student.uuid == studentUuid);

  @override
  Future<SchoolProfile> getSchoolProfile(String schoolUuid) async =>
      const SchoolProfile(
        uuid: 'school',
        schoolCode: 'S1',
        schoolName: 'Bulk School',
        isActive: true,
      );

  @override
  Future<ApiStudentPage> getStudentsPage({
    required String schoolUuid,
    int limit = 100,
    int offset = 0,
    String? search,
    String? sessionUuid,
    String? classUuid,
    String? sectionUuid,
    DateTime? createdFrom,
    DateTime? createdTo,
    String? verificationStatus,
    bool? printed,
  }) async {
    pageRequests.add({
      'school': schoolUuid,
      'offset': offset,
      'session': sessionUuid,
      'class': classUuid,
      'section': sectionUuid,
    });
    final page = students.skip(offset).take(limit).toList();
    return ApiStudentPage(
      items: page,
      total: students.length,
      offset: offset,
      limit: limit,
      hasMore: offset + page.length < students.length,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preflight reuses bindings and groups missing-data warnings', () {
    final inspection = BulkExportInspection.inspect(
      students: [
        student(1, admissionNo: ''),
        student(2, photoPath: 'mailto:not-an-image'),
      ],
      template: bulkTemplate,
      schoolName: 'Bulk School',
      sessionName: (_) => '2026–27',
      className: (_) => '10',
      sectionName: (_) => 'A',
    );

    expect(inspection.canContinue, isTrue);
    expect(
      inspection.warnings.map((issue) => issue.message),
      containsAll(['Missing student photo', 'Malformed student photo URL']),
    );
  });

  test('preflight validates bound QR data before PDF generation', () {
    final template = bulkTemplate.copyWith(
      document: bulkTemplate.document.copyWith(
        elements: const [
          DesignElement(
            id: 'qr',
            type: DesignElementType.qrCode,
            x: 4,
            y: 4,
            width: 20,
            height: 20,
            data: {'field': 'father_name'},
          ),
        ],
      ),
    );

    final missing = BulkExportInspection.inspect(
      students: [student(1, admissionNo: '')],
      template: template,
      schoolName: 'Bulk School',
      sessionName: (_) => null,
      className: (_) => null,
      sectionName: (_) => null,
    );
    expect(
      missing.warnings.map((issue) => issue.message),
      contains("Missing father's name"),
    );

    final oversized = template.copyWith(
      document: template.document.copyWith(
        elements: [
          template.document.elements.single.copyWith(
            data: {'text': List.filled(501, '€').join()},
          ),
        ],
      ),
    );
    final blocked = BulkExportInspection.inspect(
      students: [student(1)],
      template: oversized,
      schoolName: 'Bulk School',
      sessionName: (_) => null,
      className: (_) => null,
      sectionName: (_) => null,
    );
    expect(blocked.canContinue, isFalse);
    expect(
      blocked.blockingIssues.single.message,
      'QR content exceeds 1000 UTF-8 bytes',
    );
  });

  test('PDF emits exactly one stable page per distinct student', () async {
    final cards = [
      student(1, name: 'Same Name'),
      student(2, name: 'Same Name'),
      student(3, name: 'A very long student name that must remain bounded'),
      student(4, name: 'José Åström'),
    ].map((item) => PdfCardData(student: item)).toList();
    final progress = <int>[];
    final bytes = await PdfService.generateStudentCards(
      cards: cards,
      schoolName: 'Bulk School',
      template: bulkTemplate,
      onCardPrepared: (completed, _) => progress.add(completed),
    );
    final source = latin1.decode(bytes, allowInvalid: true);
    expect(
      RegExp(r'/Type\s*/Page(?!s)\b').allMatches(source).length,
      cards.length,
    );
    expect(progress, [1, 2, 3, 4]);
  });

  for (final size in [100, 500, 1000]) {
    test('generates a representative $size-card batch', () async {
      final watch = Stopwatch()..start();
      final bytes = await PdfService.generateStudentCards(
        cards: List.generate(
          size,
          (index) => PdfCardData(student: student(index)),
        ),
        schoolName: 'Bulk School',
        template: bulkTemplate.copyWith(
          document: bulkTemplate.document.copyWith(
            elements: [bulkTemplate.document.elements.first],
          ),
        ),
      );
      watch.stop();
      final source = latin1.decode(bytes, allowInvalid: true);
      expect(RegExp(r'/Type\s*/Page(?!s)\b').allMatches(source).length, size);
      // Printed output is captured by the test runner for the final benchmark report.
      // ignore: avoid_print
      print(
        'BULK_METRIC cards=$size ms=${watch.elapsedMilliseconds} bytes=${bytes.length}',
      );
    });
  }

  testWidgets(
    'selected scope is explicit and a failed export preserves selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = BulkApi([student(1)]);
      addTearDown(api.dispose);
      final export = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CardsScreen(
            schoolUuid: 'school',
            schoolName: 'Bulk School',
            api: api,
            canEdit: true,
            canDesign: false,
            canPrint: true,
            canVerify: true,
            bulkPdfAction:
                ({
                  required cards,
                  required schoolName,
                  required template,
                  required schoolLogoUrl,
                  required schoolProfile,
                  required assetBaseUrl,
                  required onCardPrepared,
                }) {
                  calls++;
                  onCardPrepared(cards.length, cards.length);
                  return export.future;
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.tap(find.byTooltip('Download filtered cards as PDF'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bulk-scope-selected')), findsOneWidget);
      expect(find.text('Selected students only (1)'), findsOneWidget);
      await tester.tap(find.text('Create PDF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('bulk-export-confirmation')), findsOneWidget);
      expect(find.text('Scope: Selected students only'), findsOneWidget);
      expect(find.text('Students/cards: 1'), findsOneWidget);
      expect(find.text('Template: Bulk template'), findsOneWidget);
      await tester.tap(find.byKey(const Key('bulk-export-confirm')));
      await tester.pump();
      expect(calls, 1);
      expect(find.byKey(const Key('bulk-export-status')), findsOneWidget);
      final disabled = tester.widget<IconButton>(
        find.byKey(const Key('bulk-export-action')),
      );
      expect(disabled.onPressed, isNull);

      export.completeError(StateError('simulated failure'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isTrue,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('bulk-export-action')))
            .onPressed,
        isNotNull,
      );
      expect(
        find.textContaining('Your filters and selection were kept'),
        findsOneWidget,
      );
    },
  );
}
