import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/services/pdf_service.dart';

const actualStudent = ApiStudent(
  uuid: 'student',
  sessionUuid: 'session',
  classUuid: 'class',
  sectionUuid: 'section',
  admissionNo: 'ADM-2026',
  fullName: 'Asha Singh',
  isActive: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final portrait in [true, false]) {
    test(
      'PDF preserves ${portrait ? 'portrait' : 'landscape'} saved page dimensions',
      () async {
        final template = CardTemplate(
          name: 'PDF page size',
          document: DesignDocument(
            elements: const [
              DesignElement(
                id: 'size-marker',
                type: DesignElementType.rectangle,
                x: 1,
                y: 1,
                width: 2,
                height: 2,
                style: {'fill_color': '#112233'},
              ),
            ],
            canvas: DesignCanvas(
              width: portrait ? 53.98 : 85.6,
              height: portrait ? 85.6 : 53.98,
            ),
          ),
        );
        final bytes = await PdfService.generateStudentCard(
          student: actualStudent,
          schoolName: 'Parity School',
          template: template,
          photoUrl: 'invalid-url',
          schoolLogoUrl: 'invalid-url',
          className: 'X',
          sectionName: 'A',
        );
        final source = latin1.decode(bytes, allowInvalid: true);
        final bounds = RegExp(
          r'/MediaBox\s*\[\s*0(?:\.0+)?\s+0(?:\.0+)?\s+([\d.]+)\s+([\d.]+)\s*\]',
        ).firstMatch(source)!;
        expect(
          double.parse(bounds[1]!),
          closeTo(template.document.canvas.width * 72 / 25.4, .01),
        );
        expect(
          double.parse(bounds[2]!),
          closeTo(template.document.canvas.height * 72 / 25.4, .01),
        );
      },
    );
  }
}
