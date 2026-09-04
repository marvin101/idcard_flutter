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
  }) async {
    final pdf = pw.Document();
    final fonts = await DesignFonts.pdfFonts();
    final images = <String, pw.MemoryImage?>{};
    for (final card in cards) {
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
      final renderer = PdfDocumentRenderer(fonts, images);
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
