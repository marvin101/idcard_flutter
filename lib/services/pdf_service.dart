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
    final pdf = pw.Document();
    final fonts = await DesignFonts.pdfFonts();
    final images = <String, pw.MemoryImage?>{};
    final scenes = <DesignRenderScene>[];
    for (var index = 0; index < cards.length; index++) {
      final card = cards[index];
      final scene = DesignRenderScene(
        document: template.document,
        bindings: DesignBindings(
          student: card.student,
          sessionName: card.sessionName,
          className: card.className,
          sectionName: card.sectionName,
          schoolName: schoolName,
          schoolProfile: schoolProfile,
        ),
        photoUrl: card.photoUrl,
        logoUrl: schoolLogoUrl,
        assetBaseUrl: assetBaseUrl,
      );
      for (final url in {
        scene.backgroundImage,
        ...scene.elements.map((e) => e.imageUrl),
      }.whereType<String>()) {
        if (!images.containsKey(url)) images[url] = await _download(url);
      }
      scenes.add(scene);
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
      for (final scene in scenes) {
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
      return pdf.save();
    }

    for (
      var pageStart = 0;
      pageStart < scenes.length;
      pageStart += plan.cardsPerPage
    ) {
      final pageScenes = scenes
          .skip(pageStart)
          .take(plan.cardsPerPage)
          .toList();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            _mm(printSettings.pageWidthMm),
            _mm(printSettings.pageHeightMm),
          ),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              for (var index = 0; index < pageScenes.length; index++)
                pw.Positioned(
                  left: _mm(plan.leftFor(index)),
                  top: _mm(plan.topFor(index)),
                  child: renderer.build(pageScenes[index]),
                ),
              if (printSettings.cropMarks)
                ..._cropMarks(plan, pageScenes.length),
            ],
          ),
        ),
      );
    }
    return pdf.save();
  }

  static Iterable<pw.Widget> _cropMarks(
    PrintSheetPlan plan,
    int cardsOnPage,
  ) sync* {
    const markLengthMm = 2.0;
    const lineWidthMm = 0.2;
    for (var index = 0; index < cardsOnPage; index++) {
      final left = plan.leftFor(index);
      final top = plan.topFor(index);
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
