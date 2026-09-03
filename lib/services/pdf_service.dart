// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/api_student.dart';
import '../models/card_template.dart';

class PdfService {
  static double _mm(double value) => value * PdfPageFormat.mm;

  static Future<Uint8List> generateStudentCard({
    required ApiStudent student,
    required String schoolName,
    required CardTemplate template,
    String? sessionName,
    String? photoUrl,
    String? schoolLogoUrl,
  }) => generateStudentCards(
    cards: [
      PdfCardData(
        student: student,
        sessionName: sessionName,
        photoUrl: photoUrl,
      ),
    ],
    schoolName: schoolName,
    template: template,
    schoolLogoUrl: schoolLogoUrl,
  );

  static Future<Uint8List> generateStudentCards({
    required List<PdfCardData> cards,
    required String schoolName,
    required CardTemplate template,
    String? schoolLogoUrl,
  }) async {
    final pdf = pw.Document();
    final logo = await _download(schoolLogoUrl);
    for (final card in cards) {
      final photo = await _download(card.photoUrl);
      final canvas = template.document.canvas;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(_mm(canvas.width), _mm(canvas.height)),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Container(
            width: _mm(canvas.width),
            height: _mm(canvas.height),
            color: _color(canvas.backgroundColor, PdfColors.white),
            child: pw.Stack(
              children: [
                for (final element in ([
                  ...template.document.elements,
                ]..sort((a, b) => a.zIndex.compareTo(b.zIndex))))
                  if (element.visible)
                    pw.Positioned(
                      left: _mm(element.x),
                      top: _mm(element.y),
                      child: pw.Transform.rotate(
                        angle: element.rotation * math.pi / 180,
                        child: pw.SizedBox(
                          width: _mm(element.width),
                          height: _mm(element.height),
                          child: _element(
                            element,
                            card,
                            schoolName,
                            photo,
                            logo,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      );
    }
    return pdf.save();
  }

  static Future<pw.MemoryImage?> _download(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty)
        return pw.MemoryImage(response.bodyBytes);
    } catch (_) {
      /* Render a placeholder when an asset is unavailable. */
    }
    return null;
  }

  static pw.Widget _element(
    DesignElement element,
    PdfCardData card,
    String schoolName,
    pw.MemoryImage? photo,
    pw.MemoryImage? logo,
  ) {
    final style = element.style;
    switch (element.type) {
      case DesignElementType.rectangle:
        return pw.Container(
          decoration: pw.BoxDecoration(
            color: _color(style['fill_color'], const PdfColor(0, 0, 0, 0)),
            border: pw.Border.all(
              color: _color(style['border_color'], const PdfColor(0, 0, 0, 0)),
              width: _mm((style['border_width'] as num?)?.toDouble() ?? 0),
            ),
            borderRadius: pw.BorderRadius.circular(
              _mm((style['corner_radius'] as num?)?.toDouble() ?? 0),
            ),
          ),
        );
      case DesignElementType.line:
        return pw.Center(
          child: pw.Container(
            height: _mm(
              math.max(.2, (style['border_width'] as num?)?.toDouble() ?? .5),
            ),
            color: _color(style['color'], PdfColors.black),
          ),
        );
      case DesignElementType.studentPhoto:
      case DesignElementType.schoolLogo:
        final image = element.type == DesignElementType.studentPhoto
            ? photo
            : logo;
        return pw.Container(
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(
              color: _color(style['border_color'], const PdfColor(0, 0, 0, 0)),
              width: _mm((style['border_width'] as num?)?.toDouble() ?? 0),
            ),
            borderRadius: pw.BorderRadius.circular(
              _mm((style['corner_radius'] as num?)?.toDouble() ?? 0),
            ),
          ),
          child: image == null
              ? pw.Center(
                  child: pw.Text(
                    element.type == DesignElementType.studentPhoto
                        ? 'PHOTO'
                        : 'LOGO',
                    style: const pw.TextStyle(
                      fontSize: 6,
                      color: PdfColors.grey600,
                    ),
                  ),
                )
              : pw.ClipRRect(
                  horizontalRadius: _mm(
                    (style['corner_radius'] as num?)?.toDouble() ?? 0,
                  ),
                  verticalRadius: _mm(
                    (style['corner_radius'] as num?)?.toDouble() ?? 0,
                  ),
                  child: pw.Image(
                    image,
                    fit: style['fit'] == 'contain'
                        ? pw.BoxFit.contain
                        : pw.BoxFit.cover,
                  ),
                ),
        );
      case DesignElementType.text:
      case DesignElementType.boundText:
      case DesignElementType.customFieldText:
        final text = _resolve(element, card, schoolName);
        final align = switch (style['alignment']) {
          'center' => pw.TextAlign.center,
          'right' => pw.TextAlign.right,
          _ => pw.TextAlign.left,
        };
        return pw.Align(
          alignment: switch (style['alignment']) {
            'center' => pw.Alignment.center,
            'right' => pw.Alignment.centerRight,
            _ => pw.Alignment.centerLeft,
          },
          child: pw.Text(
            text,
            maxLines: (style['max_lines'] as num?)?.toInt() ?? 2,
            overflow: pw.TextOverflow.clip,
            textAlign: align,
            style: pw.TextStyle(
              fontSize: _mm((style['font_size'] as num?)?.toDouble() ?? 3),
              color: _color(style['color'], PdfColors.black),
              fontWeight:
                  ((style['font_weight'] as num?)?.toInt() ?? 400) >= 600
                  ? pw.FontWeight.bold
                  : pw.FontWeight.normal,
            ),
          ),
        );
    }
  }

  static String _resolve(
    DesignElement element,
    PdfCardData card,
    String schoolName,
  ) {
    final data = element.data;
    String value;
    if (element.type == DesignElementType.text)
      value = data['text'] as String? ?? 'Text';
    else if (element.type == DesignElementType.customFieldText)
      value =
          card.student.customFields
              .where((field) => field.fieldUuid == data['field_uuid'])
              .map((field) => field.value)
              .firstOrNull ??
          (data['fallback'] as String? ?? '');
    else
      value = switch (data['field']) {
        'full_name' => card.student.fullName,
        'admission_no' => card.student.admissionNo,
        'roll_no' => card.student.rollNo ?? '',
        'stream' => card.student.stream ?? '',
        'father_name' => card.student.fatherName ?? '',
        'mother_name' => card.student.motherName ?? '',
        'dob' => _date(card.student.dob),
        'gender' => card.student.gender ?? '',
        'blood_group' => card.student.bloodGroup ?? '',
        'mobile' => card.student.mobile ?? '',
        'aadhaar' => card.student.aadhaar ?? '',
        'address' => card.student.address ?? '',
        'session' => card.sessionName ?? '',
        'class' => card.className ?? '',
        'section' => card.sectionName ?? '',
        'school_name' => schoolName,
        _ => '',
      };
    if (value.isEmpty) value = data['fallback'] as String? ?? '';
    return '${data['prefix'] ?? ''}$value${data['suffix'] ?? ''}';
  }

  static String _date(DateTime? value) => value == null
      ? ''
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  static PdfColor _color(Object? value, PdfColor fallback) {
    if (value is! String) return fallback;
    final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
    return parsed == null ? fallback : PdfColor.fromInt(0xff000000 | parsed);
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
