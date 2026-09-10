import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/print_sheet.dart';
import 'package:idcard_flutter/services/pdf_service.dart';
import 'package:idcard_flutter/services/print_preset_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('print settings preserve calibration through JSON', () {
    const settings = PrintSheetSettings(
      mode: PrintLayoutMode.sheet,
      paperSize: PrintPaperSize.letter,
      orientation: PrintPaperOrientation.landscape,
      marginMm: 8.5,
      gapMm: 2,
      cropMarks: true,
      sides: PrintSides.duplex,
      flipEdge: DuplexFlipEdge.shortEdge,
      frontOffsetXmm: 1.25,
      frontOffsetYmm: -0.5,
      backOffsetXmm: -1.75,
      backOffsetYmm: 2.25,
    );

    final decoded = PrintSheetSettings.fromJson(settings.toJson());

    expect(decoded.mode, PrintLayoutMode.sheet);
    expect(decoded.paperSize, PrintPaperSize.letter);
    expect(decoded.orientation, PrintPaperOrientation.landscape);
    expect(decoded.marginMm, 8.5);
    expect(decoded.cropMarks, isTrue);
    expect(decoded.sides, PrintSides.duplex);
    expect(decoded.flipEdge, DuplexFlipEdge.shortEdge);
    expect(decoded.frontOffsetXmm, 1.25);
    expect(decoded.frontOffsetYmm, -0.5);
    expect(decoded.backOffsetXmm, -1.75);
    expect(decoded.backOffsetYmm, 2.25);
  });

  test('calibration moves front and back slots independently', () {
    final plan = PrintSheetPlan.calculate(
      settings: const PrintSheetSettings(
        mode: PrintLayoutMode.sheet,
        sides: PrintSides.duplex,
        frontOffsetXmm: 1.5,
        frontOffsetYmm: -0.5,
        backOffsetXmm: -0.75,
        backOffsetYmm: 2,
      ),
      cardWidthMm: 85.6,
      cardHeightMm: 53.98,
      cardCount: 1,
    );

    expect(plan.leftFor(0) - plan.leftFor(0, back: true), 2.25);
    expect(plan.topFor(0, back: true) - plan.topFor(0), 2.5);
  });

  test('calibration rejects unsafe offsets', () {
    final plan = PrintSheetPlan.calculate(
      settings: const PrintSheetSettings(
        mode: PrintLayoutMode.sheet,
        frontOffsetXmm: 20.1,
      ),
      cardWidthMm: 85.6,
      cardHeightMm: 53.98,
      cardCount: 1,
    );

    expect(plan.isValid, isFalse);
    expect(plan.validationError, contains('-20 and 20 mm'));
  });

  test('calibration cannot move the card grid off the paper', () {
    final plan = PrintSheetPlan.calculate(
      settings: const PrintSheetSettings(
        mode: PrintLayoutMode.sheet,
        frontOffsetXmm: 20,
      ),
      cardWidthMm: 85.6,
      cardHeightMm: 53.98,
      cardCount: 1,
    );

    expect(plan.isValid, isFalse);
    expect(plan.validationError, contains('outside the selected paper'));
  });

  test(
    'preset store is school scoped and updates names case-insensitively',
    () async {
      const store = PrintPresetStore();
      final first = await store.save(
        schoolUuid: 'school-a',
        name: 'Office printer',
        settings: const PrintSheetSettings(mode: PrintLayoutMode.sheet),
      );
      final updated = await store.save(
        schoolUuid: 'school-a',
        name: 'OFFICE PRINTER',
        settings: const PrintSheetSettings(
          mode: PrintLayoutMode.sheet,
          frontOffsetXmm: 1,
        ),
      );

      expect(updated.id, first.id);
      expect(await store.load('school-b'), isEmpty);
      final schoolPresets = await store.load('school-a');
      expect(schoolPresets, hasLength(1));
      expect(schoolPresets.single.settings.frontOffsetXmm, 1);

      await store.delete('school-a', first.id);
      expect(await store.load('school-a'), isEmpty);
    },
  );

  test('duplex calibration PDF contains front and back pages', () async {
    final bytes = await PdfService.generatePrintCalibrationSheet(
      const PrintSheetSettings(
        mode: PrintLayoutMode.sheet,
        sides: PrintSides.duplex,
        frontOffsetXmm: 1,
        backOffsetYmm: -1,
      ),
    );
    final source = latin1.decode(bytes, allowInvalid: true);

    expect(RegExp(r'/Type\s*/Page(?!s)\b').allMatches(source).length, 2);
  });
}
