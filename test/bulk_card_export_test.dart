import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/academic_session.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/bulk_card_export.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/print_sheet.dart';
import 'package:idcard_flutter/models/school_class.dart';
import 'package:idcard_flutter/models/school_profile.dart';
import 'package:idcard_flutter/models/section.dart';
import 'package:idcard_flutter/screens/cards_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/services/pdf_service.dart';
import 'package:idcard_flutter/services/print_preset_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final duplexBulkTemplate = bulkTemplate.copyWith(
  backDocument: const DesignDocument(
    canvas: DesignCanvas(width: 85.6, height: 53.98),
    elements: [
      DesignElement(
        id: 'back-admission',
        type: DesignElementType.boundText,
        x: 4,
        y: 4,
        width: 50,
        height: 8,
        data: {'field': 'admission_no'},
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
  Future<CardTemplate> getCardTemplate(String schoolUuid) async =>
      duplexBulkTemplate;

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
  setUp(() => SharedPreferences.setMockInitialValues({}));

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

  test('preflight reports missing values inside multi-field QR payloads', () {
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
            data: {
              'fields': [
                {'field': 'full_name', 'label': 'Full name'},
                {'field': 'father_name', 'label': "Father's name"},
              ],
              'format': 'json',
            },
          ),
        ],
      ),
    );

    final inspection = BulkExportInspection.inspect(
      students: [student(1)],
      template: template,
      schoolName: 'Bulk School',
      sessionName: (_) => null,
      className: (_) => null,
      sectionName: (_) => null,
    );

    expect(
      inspection.warnings.map((issue) => issue.message),
      contains("Missing Father's name"),
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

  test('A4 sheet plan preserves card size and calculates capacity', () {
    final plan = PrintSheetPlan.calculate(
      settings: const PrintSheetSettings(mode: PrintLayoutMode.sheet),
      cardWidthMm: 85.6,
      cardHeightMm: 53.98,
      cardCount: 10,
    );

    expect(plan.isValid, isTrue);
    expect(plan.columns, 2);
    expect(plan.rows, 4);
    expect(plan.cardsPerPage, 8);
    expect(plan.pageCount, 2);
    expect(plan.leftFor(0), greaterThanOrEqualTo(10));
    expect(plan.topFor(0), greaterThanOrEqualTo(10));
    expect(plan.leftFor(7) + 85.6, lessThanOrEqualTo(200));
    expect(plan.topFor(7) + 53.98, lessThanOrEqualTo(287));
  });

  test('duplex slot mapping mirrors for page orientation and flip edge', () {
    final portrait = PrintSheetPlan.calculate(
      settings: const PrintSheetSettings(mode: PrintLayoutMode.sheet),
      cardWidthMm: 85.6,
      cardHeightMm: 53.98,
      cardCount: 3,
    );
    expect(portrait.backSlotFor(0, DuplexFlipEdge.longEdge), 1);
    expect(portrait.backSlotFor(1, DuplexFlipEdge.longEdge), 0);
    expect(portrait.backSlotFor(0, DuplexFlipEdge.shortEdge), 6);
    expect(portrait.backSlotFor(1, DuplexFlipEdge.shortEdge), 7);

    final landscape = PrintSheetPlan.calculate(
      settings: const PrintSheetSettings(
        mode: PrintLayoutMode.sheet,
        orientation: PrintPaperOrientation.landscape,
      ),
      cardWidthMm: 85.6,
      cardHeightMm: 53.98,
      cardCount: 3,
    );
    expect(landscape.backSlotFor(0, DuplexFlipEdge.longEdge), 6);
    expect(landscape.backSlotFor(0, DuplexFlipEdge.shortEdge), 2);
  });

  test('duplex plan reports PDF pages separately from physical sheets', () {
    final plan = PrintSheetPlan.calculate(
      settings: const PrintSheetSettings(
        mode: PrintLayoutMode.sheet,
        sides: PrintSides.duplex,
      ),
      cardWidthMm: 85.6,
      cardHeightMm: 53.98,
      cardCount: 10,
    );
    expect(plan.physicalSheetCount, 2);
    expect(plan.pdfPageCount, 4);
  });

  test('back-side preflight runs only for duplex output', () {
    const template = CardTemplate(
      name: 'Back preflight',
      document: DesignDocument(
        canvas: DesignCanvas(width: 85.6, height: 53.98),
        elements: [],
      ),
      backDocument: DesignDocument(
        canvas: DesignCanvas(width: 85.6, height: 53.98),
        elements: [
          DesignElement(
            id: 'back-photo',
            type: DesignElementType.studentPhoto,
            x: 5,
            y: 5,
            width: 20,
            height: 20,
          ),
          DesignElement(
            id: 'back-father',
            type: DesignElementType.boundText,
            x: 30,
            y: 5,
            width: 30,
            height: 8,
            data: {'field': 'father_name'},
          ),
        ],
      ),
    );
    BulkExportInspection inspect(bool includeBack) =>
        BulkExportInspection.inspect(
          students: [student(1)],
          template: template,
          schoolName: 'Bulk School',
          sessionName: (_) => '2026–27',
          className: (_) => '10',
          sectionName: (_) => 'A',
          includeBack: includeBack,
        );

    expect(inspect(false).warnings, isEmpty);
    expect(
      inspect(true).warnings.map((issue) => issue.message),
      containsAll(['Missing student photo', "Missing father's name"]),
    );
  });

  for (final configuration in [
    (
      size: PrintPaperSize.a4,
      orientation: PrintPaperOrientation.landscape,
      columns: 3,
      rows: 3,
    ),
    (
      size: PrintPaperSize.letter,
      orientation: PrintPaperOrientation.portrait,
      columns: 2,
      rows: 4,
    ),
    (
      size: PrintPaperSize.letter,
      orientation: PrintPaperOrientation.landscape,
      columns: 2,
      rows: 3,
    ),
  ]) {
    test(
      '${configuration.size.name} ${configuration.orientation.name} calculates '
      'an exact-size grid',
      () {
        final plan = PrintSheetPlan.calculate(
          settings: PrintSheetSettings(
            mode: PrintLayoutMode.sheet,
            paperSize: configuration.size,
            orientation: configuration.orientation,
          ),
          cardWidthMm: 85.6,
          cardHeightMm: 53.98,
          cardCount: 20,
        );
        expect(plan.isValid, isTrue);
        expect(plan.columns, configuration.columns);
        expect(plan.rows, configuration.rows);
        expect(
          plan.leftFor(plan.cardsPerPage - 1) + plan.cardWidthMm,
          lessThanOrEqualTo(plan.settings.pageWidthMm - plan.settings.marginMm),
        );
        expect(
          plan.topFor(plan.cardsPerPage - 1) + plan.cardHeightMm,
          lessThanOrEqualTo(
            plan.settings.pageHeightMm - plan.settings.marginMm,
          ),
        );
      },
    );
  }

  test('sheet plan rejects layouts that would scale or clip cards', () {
    final plan = PrintSheetPlan.calculate(
      settings: const PrintSheetSettings(
        mode: PrintLayoutMode.sheet,
        marginMm: 100,
      ),
      cardWidthMm: 85.6,
      cardHeightMm: 53.98,
      cardCount: 1,
    );

    expect(plan.isValid, isFalse);
    expect(plan.validationError, contains('does not fit'));
  });

  test('sheet PDF emits the calculated number of physical pages', () async {
    final cards = List.generate(
      10,
      (index) => PdfCardData(student: student(index)),
    );
    final bytes = await PdfService.generateStudentCards(
      cards: cards,
      schoolName: 'Bulk School',
      template: bulkTemplate,
      printSettings: const PrintSheetSettings(
        mode: PrintLayoutMode.sheet,
        cropMarks: true,
      ),
    );
    final source = latin1.decode(bytes, allowInvalid: true);
    expect(RegExp(r'/Type\s*/Page(?!s)\b').allMatches(source).length, 2);
  });

  test('duplex sheet PDF alternates front and mirrored back pages', () async {
    final cards = List.generate(
      10,
      (index) => PdfCardData(student: student(index)),
    );
    final bytes = await PdfService.generateStudentCards(
      cards: cards,
      schoolName: 'Bulk School',
      template: duplexBulkTemplate,
      printSettings: const PrintSheetSettings(
        mode: PrintLayoutMode.sheet,
        sides: PrintSides.duplex,
        flipEdge: DuplexFlipEdge.shortEdge,
        cropMarks: true,
      ),
    );
    final source = latin1.decode(bytes, allowInvalid: true);
    expect(RegExp(r'/Type\s*/Page(?!s)\b').allMatches(source).length, 4);
  });

  test('one-card duplex PDF emits one front/back pair per student', () async {
    final bytes = await PdfService.generateStudentCards(
      cards: List.generate(3, (index) => PdfCardData(student: student(index))),
      schoolName: 'Bulk School',
      template: duplexBulkTemplate,
      printSettings: const PrintSheetSettings(sides: PrintSides.duplex),
    );
    final source = latin1.decode(bytes, allowInvalid: true);
    expect(RegExp(r'/Type\s*/Page(?!s)\b').allMatches(source).length, 6);
  });

  test('duplex output requires a matching back design', () async {
    await expectLater(
      PdfService.generateStudentCards(
        cards: [PdfCardData(student: student(1))],
        schoolName: 'Bulk School',
        template: bulkTemplate,
        printSettings: const PrintSheetSettings(sides: PrintSides.duplex),
      ),
      throwsA(isA<ArgumentError>()),
    );
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

  testWidgets('sheet controls preview capacity and reach PDF generation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = BulkApi([student(1)]);
    addTearDown(api.dispose);
    PrintSheetSettings? receivedSettings;
    await tester.pumpWidget(
      MaterialApp(
        home: CardsScreen(
          schoolUuid: 'school',
          schoolName: 'Bulk School',
          api: api,
          canEdit: true,
          canDesign: false,
          canPrint: true,
          bulkPdfAction:
              ({
                required cards,
                required schoolName,
                required template,
                required schoolLogoUrl,
                required schoolProfile,
                required assetBaseUrl,
                required printSettings,
                required onCardPrepared,
              }) async {
                receivedSettings = printSettings;
                onCardPrepared(cards.length, cards.length);
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bulk-export-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('print-layout-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Multiple cards per sheet').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('print-sides')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Front and back (duplex)').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('print-duplex-flip-edge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('print-duplex-flip-edge')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Flip on short edge').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('2 × 4 = 8 cards per A4'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('print-crop-marks')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('print-crop-marks')));
    await tester.pump();
    await tester.ensureVisible(find.text('Create PDF'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create PDF'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text(
        'PDF pages: 2 • Physical sheets: 1 • 2 × 4 = 8 cards per sheet',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('bulk-sheet-settings'))).data,
      contains('crop marks'),
    );
    await tester.tap(find.byKey(const Key('bulk-export-confirm')));
    await tester.pumpAndSettle();
    expect(receivedSettings?.mode, PrintLayoutMode.sheet);
    expect(receivedSettings?.paperSize, PrintPaperSize.a4);
    expect(receivedSettings?.cropMarks, isTrue);
    expect(receivedSettings?.sides, PrintSides.duplex);
    expect(receivedSettings?.flipEdge, DuplexFlipEdge.shortEdge);
  });

  testWidgets('individual card print offers duplex and flip-edge controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = BulkApi([student(1)]);
    addTearDown(api.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: CardsScreen(
          schoolUuid: 'school',
          schoolName: 'Bulk School',
          api: api,
          canEdit: true,
          canDesign: false,
          canPrint: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.print_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('individual-print-sides-dialog')), findsOne);
    await tester.tap(find.byKey(const Key('individual-print-sides')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Front and back (duplex)').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('individual-print-flip-edge')), findsOne);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('saved print preset restores sheet and calibration settings', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await const PrintPresetStore().save(
      schoolUuid: 'school',
      name: 'Office duplex',
      settings: const PrintSheetSettings(
        mode: PrintLayoutMode.sheet,
        paperSize: PrintPaperSize.letter,
        orientation: PrintPaperOrientation.landscape,
        marginMm: 7,
        gapMm: 3,
        cropMarks: true,
        sides: PrintSides.duplex,
        flipEdge: DuplexFlipEdge.shortEdge,
        frontOffsetXmm: 1.5,
        frontOffsetYmm: -0.5,
        backOffsetXmm: -1,
        backOffsetYmm: 2,
      ),
    );
    final api = BulkApi([student(1)]);
    addTearDown(api.dispose);
    PrintSheetSettings? receivedSettings;
    await tester.pumpWidget(
      MaterialApp(
        home: CardsScreen(
          schoolUuid: 'school',
          schoolName: 'Bulk School',
          api: api,
          canEdit: true,
          canDesign: false,
          canPrint: true,
          bulkPdfAction:
              ({
                required cards,
                required schoolName,
                required template,
                required schoolLogoUrl,
                required schoolProfile,
                required assetBaseUrl,
                required printSettings,
                required onCardPrepared,
              }) async {
                receivedSettings = printSettings;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('bulk-export-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('print-preset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Office duplex').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Letter landscape sheet'), findsOneWidget);
    await tester.ensureVisible(find.text('Create PDF'));
    await tester.tap(find.text('Create PDF'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.textContaining('Calibration: front X 1.5 mm, Y -0.5 mm'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('bulk-export-confirm')));
    await tester.pumpAndSettle();

    expect(receivedSettings?.paperSize, PrintPaperSize.letter);
    expect(receivedSettings?.orientation, PrintPaperOrientation.landscape);
    expect(receivedSettings?.frontOffsetXmm, 1.5);
    expect(receivedSettings?.backOffsetYmm, 2);
  });

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
                  required printSettings,
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

  testWidgets(
    'print basket survives filter reloads and is available as an export scope',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = BulkApi([student(1), student(2)]);
      addTearDown(api.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: CardsScreen(
            schoolUuid: 'school',
            schoolName: 'Bulk School',
            api: api,
            canEdit: true,
            canDesign: false,
            canPrint: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.tap(find.byKey(const Key('add-selection-to-print-basket')));
      await tester.pump();
      expect(
        tester.widget<Checkbox>(find.byType(Checkbox).first).value,
        isFalse,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('print-basket-action')))
            .tooltip,
        'Print Basket (1)',
      );

      await tester.enterText(find.byType(TextField).first, 'another filter');
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('print-basket-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('print-basket-dialog')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('print-basket-dialog')),
          matching: find.text('Student 1'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('bulk-export-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bulk-scope-print-basket')), findsOneWidget);
      expect(find.text('Print Basket (1)'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('print-basket-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('clear-print-basket')));
      await tester.pump();
      expect(
        find.text(
          'The basket is empty. Select cards and use Add to Print Basket.',
        ),
        findsOneWidget,
      );
    },
  );
}
