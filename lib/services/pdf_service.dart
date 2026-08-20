import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/api_student.dart';

class PdfService {
  // Standard CR80 ID-card size.
  static const double _cardWidthMm = 85.60;
  static const double _cardHeightMm = 53.98;

  static double _mm(double value) {
    return value * PdfPageFormat.mm;
  }

  static Future<Uint8List> generateStudentCard({
    required ApiStudent student,
    required String schoolName,
    String? sessionName,
    String? photoUrl,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? photo;

    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(photoUrl));

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          photo = pw.MemoryImage(response.bodyBytes);
        }
      } catch (_) {
        // Continue without the photo if it cannot be downloaded.
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(_mm(_cardWidthMm), _mm(_cardHeightMm)),
        margin: pw.EdgeInsets.zero,
        build: (context) {
          return pw.Container(
            width: _mm(_cardWidthMm),
            height: _mm(_cardHeightMm),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: PdfColors.grey600, width: 0.7),
            ),
            child: pw.Padding(
              padding: pw.EdgeInsets.fromLTRB(
                _mm(2.5),
                _mm(2),
                _mm(2.5),
                _mm(1.5),
              ),
              child: pw.Column(
                children: [
                  // ---------------------------------------------------------
                  // SCHOOL NAME
                  // ---------------------------------------------------------
                  pw.Text(
                    schoolName.toUpperCase(),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),

                  pw.SizedBox(height: _mm(0.5)),

                  // ---------------------------------------------------------
                  // CARD TITLE
                  // ---------------------------------------------------------
                  pw.Text(
                    'STUDENT ID CARD',
                    style: pw.TextStyle(
                      fontSize: 5.5,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.8,
                      color: PdfColors.grey700,
                    ),
                  ),

                  pw.SizedBox(height: _mm(0.8)),

                  // ---------------------------------------------------------
                  // PHOTO + BASIC INFORMATION
                  // ---------------------------------------------------------
                  pw.SizedBox(
                    height: _mm(20),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // PHOTO
                        pw.Container(
                          width: _mm(16),
                          height: _mm(20),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.grey100,
                            border: pw.Border.all(
                              color: PdfColors.blue900,
                              width: 1.2,
                            ),
                          ),
                          child: photo == null
                              ? pw.Center(
                                  child: pw.Text(
                                    'PHOTO',
                                    style: pw.TextStyle(
                                      fontSize: 6,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey600,
                                    ),
                                  ),
                                )
                              : pw.Image(photo, fit: pw.BoxFit.cover),
                        ),

                        pw.SizedBox(width: _mm(2)),

                        // BASIC INFORMATION
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                student.fullName.trim().isEmpty
                                    ? 'Student'
                                    : student.fullName.trim(),
                                maxLines: 1,
                                overflow: pw.TextOverflow.clip,
                                style: pw.TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.blue900,
                                ),
                              ),

                              pw.SizedBox(height: _mm(0.6)),

                              _field('Adm. No.', student.admissionNo),

                              _field('Roll No.', student.rollNo),

                              _field('Stream', student.stream),

                              _field('Blood', student.bloodGroup),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: _mm(1)),

                  // ---------------------------------------------------------
                  // DIVIDER
                  // ---------------------------------------------------------
                  pw.Container(
                    height: 0.5,
                    width: double.infinity,
                    color: PdfColors.grey400,
                  ),

                  pw.SizedBox(height: _mm(1)),

                  // ---------------------------------------------------------
                  // PERSONAL INFORMATION
                  // ---------------------------------------------------------
                  pw.SizedBox(
                    height: _mm(7.5),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _field('Father', student.fatherName),
                              _field('Mother', student.motherName),
                              _field('DOB', _formatDate(student.dob)),
                            ],
                          ),
                        ),

                        pw.SizedBox(width: _mm(2)),

                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _field('Mobile', student.mobile),
                              _field('Aadhaar', student.aadhaar),
                              _field('Address', student.address),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: _mm(1)),

                  // ---------------------------------------------------------
                  // PRINCIPAL SIGNATURE
                  // ---------------------------------------------------------
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Container(
                      width: _mm(22),
                      height: _mm(5),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                          color: PdfColors.grey500,
                          width: 0.6,
                        ),
                      ),
                      alignment: pw.Alignment.bottomCenter,
                      padding: pw.EdgeInsets.only(bottom: _mm(0.5)),
                      child: pw.Text(
                        "Principal's Signature",
                        style: pw.TextStyle(
                          fontSize: 4.5,
                          color: PdfColors.grey700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  pw.SizedBox(height: _mm(0.6)),

                  // ---------------------------------------------------------
                  // SESSION BAR
                  // ---------------------------------------------------------
                  pw.Container(
                    width: double.infinity,
                    height: _mm(5),
                    color: PdfColors.blue900,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'Session: ${sessionName ?? 'Not specified'}',
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      style: pw.TextStyle(
                        fontSize: 5.5,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _field(String label, String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return pw.SizedBox(height: _mm(2.1));
    }

    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: _mm(0.35)),
      child: pw.RichText(
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
        text: pw.TextSpan(
          style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey900),
          children: [
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: text),
          ],
        ),
      ),
    );
  }

  static String? _formatDate(DateTime? value) {
    if (value == null) {
      return null;
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');

    return '$day/$month/${value.year}';
  }
}
