// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/api_student.dart';
import '../models/card_template.dart';
import '../models/design_bindings.dart';
import '../models/school_profile.dart';
import '../models/design_render_scene.dart';
import '../models/print_sheet.dart';
import 'design_fonts.dart';
import 'pdf_document_renderer.dart';

class PdfService {
  static double _mm(double value) => value * PdfPageFormat.mm;

  static Future<Uint8List> generateStudentCard({
    required ApiStudent student,
    required String schoolName,
    required CardTemplate template,
    String? sessionName,
    String? className,
    String? sectionName,
    String? photoUrl,
    String? schoolLogoUrl,
    SchoolProfile? schoolProfile,
    String? assetBaseUrl,
    PrintSheetSettings printSettings = const PrintSheetSettings(),
  }) => generateStudentCards(
    cards: [
      PdfCardData(
        student: student,
        sessionName: sessionName,
        className: className,
        sectionName: sectionName,
        photoUrl: photoUrl,
      ),
    ],
    schoolName: schoolName,
    template: template,
    schoolLogoUrl: schoolLogoUrl,
    schoolProfile: schoolProfile,
    assetBaseUrl: assetBaseUrl,
    printSettings: printSettings,
  );

  static Future<Uint8List> generateStudentCards({
    required List<PdfCardData> cards,
    required String schoolName,
    required CardTemplate template,
    String? schoolLogoUrl,
    SchoolProfile? schoolProfile,
    String? assetBaseUrl,
    void Function(int completed, int total)? onCardPrepared,
    PrintSheetSettings printSettings = const PrintSheetSettings(),
  }) async {
    final backDocument = template.backDocument;
    if (printSettings.isDuplex && backDocument == null) {
      throw ArgumentError(
        'Duplex PDF output requires a template with a back design.',
      );
    }
    if (printSettings.isDuplex &&
        ((backDocument!.canvas.width - template.document.canvas.width).abs() >
                .001 ||
            (backDocument.canvas.height - template.document.canvas.height)
                    .abs() >
                .001)) {
      throw ArgumentError(
        'Front and back canvas dimensions must match for duplex PDF output.',
      );
    }
    final pdf = pw.Document();
    final fonts = await DesignFonts.pdfFonts();
    final images = <String, pw.MemoryImage?>{};
    final frontScenes = <DesignRenderScene>[];
    final backScenes = <DesignRenderScene>[];
    for (var index = 0; index < cards.length; index++) {
      final card = cards[index];
      final bindings = DesignBindings(
        student: card.student,
        sessionName: card.sessionName,
        className: card.className,
        sectionName: card.sectionName,
        schoolName: schoolName,
        schoolProfile: schoolProfile,
      );
      final scenes = [
        DesignRenderScene(
          document: template.document,
          bindings: bindings,
          photoUrl: card.photoUrl,
          logoUrl: schoolLogoUrl,
          assetBaseUrl: assetBaseUrl,
        ),
        if (printSettings.isDuplex)
          DesignRenderScene(
            document: backDocument!,
            bindings: bindings,
            photoUrl: card.photoUrl,
            logoUrl: schoolLogoUrl,
            assetBaseUrl: assetBaseUrl,
          ),
      ];
      frontScenes.add(scenes.first);
      if (printSettings.isDuplex) backScenes.add(scenes.last);
      for (final scene in scenes) {
        for (final url in {
          scene.backgroundImage,
          ...scene.elements.map((e) => e.imageUrl),
        }.whereType<String>()) {
          if (!images.containsKey(url)) images[url] = await _download(url);
        }
      }
      onCardPrepared?.call(index + 1, cards.length);
      if ((index + 1) % 25 == 0) {
        // Keep the application responsive while preparing large local PDFs.
        await Future<void>.delayed(Duration.zero);
      }
    }

    final canvas = template.document.canvas;
    final plan = PrintSheetPlan.calculate(
      settings: printSettings,
      cardWidthMm: canvas.width,
      cardHeightMm: canvas.height,
      cardCount: cards.length,
    );
    if (!plan.isValid) {
      throw ArgumentError(plan.validationError);
    }
    final renderer = PdfDocumentRenderer(fonts, images);
    if (printSettings.mode == PrintLayoutMode.oneCardPerPage) {
      for (var index = 0; index < frontScenes.length; index++) {
        for (final scene in [
          frontScenes[index],
          if (printSettings.isDuplex) backScenes[index],
        ]) {
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(
                _mm(scene.canvas.width),
                _mm(scene.canvas.height),
              ),
              margin: pw.EdgeInsets.zero,
              build: (_) => renderer.build(scene),
            ),
          );
        }
      }
      return pdf.save();
    }

    for (
      var pageStart = 0;
      pageStart < frontScenes.length;
      pageStart += plan.cardsPerPage
    ) {
      final pageFronts = frontScenes
          .skip(pageStart)
          .take(plan.cardsPerPage)
          .toList();
      _addSheetPage(
        pdf: pdf,
        renderer: renderer,
        scenes: pageFronts,
        slots: List.generate(pageFronts.length, (index) => index),
        plan: plan,
      );
      if (printSettings.isDuplex) {
        final pageBacks = backScenes
            .skip(pageStart)
            .take(plan.cardsPerPage)
            .toList();
        _addSheetPage(
          pdf: pdf,
          renderer: renderer,
          scenes: pageBacks,
          slots: List.generate(
            pageBacks.length,
            (index) => plan.backSlotFor(index, printSettings.flipEdge),
          ),
          plan: plan,
          back: true,
        );
      }
    }
    return pdf.save();
  }

  static Future<Uint8List> generatePrintCalibrationSheet(
    PrintSheetSettings settings,
  ) async {
    final calibrated = settings.copyWith(mode: PrintLayoutMode.sheet);
    final offsets = [
      calibrated.frontOffsetXmm,
      calibrated.frontOffsetYmm,
      calibrated.backOffsetXmm,
      calibrated.backOffsetYmm,
    ];
    if (offsets.any((value) => !value.isFinite || value.abs() > 20)) {
      throw ArgumentError('Calibration offsets must be between -20 and 20 mm.');
    }
    if (!calibrated.marginMm.isFinite ||
        calibrated.marginMm < 0 ||
        calibrated.marginMm * 2 >= calibrated.pageWidthMm ||
        calibrated.marginMm * 2 >= calibrated.pageHeightMm) {
      throw ArgumentError('Calibration sheet margins do not fit the paper.');
    }
    final pdf = pw.Document();
    for (final back in [false, if (calibrated.isDuplex) true]) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            _mm(calibrated.pageWidthMm),
            _mm(calibrated.pageHeightMm),
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) => _calibrationPage(calibrated, back: back),
        ),
      );
    }
    return pdf.save();
  }

  static pw.Widget _calibrationPage(
    PrintSheetSettings settings, {
    required bool back,
  }) {
    final xOffset = back ? settings.backOffsetXmm : settings.frontOffsetXmm;
    final yOffset = back ? settings.backOffsetYmm : settings.frontOffsetYmm;
    final width = settings.pageWidthMm;
    final height = settings.pageHeightMm;
    final centerX = width / 2 + xOffset;
    final centerY = height / 2 + yOffset;
    final verticals = <double>[
      for (double x = 10; x < width; x += 10) x + xOffset,
    ].where((x) => x > 0 && x < width);
    final horizontals = <double>[
      for (double y = 10; y < height; y += 10) y + yOffset,
    ].where((y) => y > 0 && y < height);
    return pw.Stack(
      children: [
        for (final x in verticals)
          pw.Positioned(
            left: _mm(x),
            top: 0,
            child: pw.Container(
              width: _mm(.1),
              height: _mm(height),
              color: PdfColors.grey300,
            ),
          ),
        for (final y in horizontals)
          pw.Positioned(
            left: 0,
            top: _mm(y),
            child: pw.Container(
              width: _mm(width),
              height: _mm(.1),
              color: PdfColors.grey300,
            ),
          ),
        pw.Positioned(
          left: _mm(settings.marginMm + xOffset),
          top: _mm(settings.marginMm + yOffset),
          child: pw.Container(
            width: _mm(width - settings.marginMm * 2),
            height: _mm(height - settings.marginMm * 2),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: _mm(.25)),
            ),
          ),
        ),
        pw.Positioned(
          left: _mm(centerX - 15),
          top: _mm(centerY - .15),
          child: pw.Container(
            width: _mm(30),
            height: _mm(.3),
            color: PdfColors.black,
          ),
        ),
        pw.Positioned(
          left: _mm(centerX - .15),
          top: _mm(centerY - 15),
          child: pw.Container(
            width: _mm(.3),
            height: _mm(30),
            color: PdfColors.black,
          ),
        ),
        pw.Positioned(
          left: _mm(15 + xOffset),
          top: _mm(15 + yOffset),
          child: pw.Text(
            'CampusID print calibration - ${back ? 'BACK' : 'FRONT'}\n'
            '${settings.paperLabel} ${settings.orientationLabel} | print at 100% / Actual size\n'
            'Applied offset: X ${xOffset.toStringAsFixed(1)} mm, Y ${yOffset.toStringAsFixed(1)} mm',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  static void _addSheetPage({
    required pw.Document pdf,
    required PdfDocumentRenderer renderer,
    required List<DesignRenderScene> scenes,
    required List<int> slots,
    required PrintSheetPlan plan,
    bool back = false,
  }) {
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          _mm(plan.settings.pageWidthMm),
          _mm(plan.settings.pageHeightMm),
        ),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(
          children: [
            for (var index = 0; index < scenes.length; index++)
              pw.Positioned(
                left: _mm(plan.leftFor(slots[index], back: back)),
                top: _mm(plan.topFor(slots[index], back: back)),
                child: renderer.build(scenes[index]),
              ),
            if (plan.settings.cropMarks) ..._cropMarks(plan, slots, back: back),
          ],
        ),
      ),
    );
  }

  static Iterable<pw.Widget> _cropMarks(
    PrintSheetPlan plan,
    Iterable<int> slots, {
    bool back = false,
  }) sync* {
    const markLengthMm = 2.0;
    const lineWidthMm = 0.2;
    for (final index in slots) {
      final left = plan.leftFor(index, back: back);
      final top = plan.topFor(index, back: back);
      final right = left + plan.cardWidthMm;
      final bottom = top + plan.cardHeightMm;

      yield* _cornerMarks(left, top, -1, -1, markLengthMm, lineWidthMm);
      yield* _cornerMarks(right, top, 1, -1, markLengthMm, lineWidthMm);
      yield* _cornerMarks(left, bottom, -1, 1, markLengthMm, lineWidthMm);
      yield* _cornerMarks(right, bottom, 1, 1, markLengthMm, lineWidthMm);
    }
  }

  static Iterable<pw.Widget> _cornerMarks(
    double x,
    double y,
    int horizontalDirection,
    int verticalDirection,
    double length,
    double width,
  ) sync* {
    final horizontalLeft = horizontalDirection < 0 ? x - length : x;
    final verticalTop = verticalDirection < 0 ? y - length : y;
    yield pw.Positioned(
      left: _mm(horizontalLeft),
      top: _mm(y - width / 2),
      child: pw.Container(
        width: _mm(length),
        height: _mm(width),
        color: PdfColors.black,
      ),
    );
    yield pw.Positioned(
      left: _mm(x - width / 2),
      top: _mm(verticalTop),
      child: pw.Container(
        width: _mm(width),
        height: _mm(length),
        color: PdfColors.black,
      ),
    );
  }

  static Future<pw.MemoryImage?> _download(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return pw.MemoryImage(response.bodyBytes);
      }
    } catch (_) {
      // Unavailable assets use the same scene bounds and background fallback.
    }
    return null;
  }
}

class PdfCardData {
  const PdfCardData({
    required this.student,
    this.sessionName,
    this.className,
    this.sectionName,
    this.photoUrl,
  });
  final ApiStudent student;
  final String? sessionName, className, sectionName, photoUrl;
}
