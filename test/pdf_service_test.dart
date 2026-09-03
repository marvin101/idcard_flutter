import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/student_field.dart';
import 'package:idcard_flutter/services/pdf_service.dart';

void main() {
  test('v2 PDF renders every card and safely resolves custom data', () async {
    final cards = List.generate(
      3,
      (index) => PdfCardData(
        student: ApiStudent(
          uuid: 'student-$index',
          sessionUuid: 'session',
          classUuid: 'class',
          sectionUuid: 'section',
          admissionNo: 'ADM-$index',
          fullName: 'Student $index',
          isActive: true,
          customFields: const [
            StudentCustomFieldValue(
              fieldUuid: '11111111-1111-1111-1111-111111111111',
              value: 'Blue',
            ),
          ],
        ),
        sessionName: '2026-2027',
        className: 'X',
        sectionName: 'A',
        photoUrl: 'not-a-valid-url',
      ),
    );
    final template = CardTemplate(
      name: 'PDF v2',
      document: DesignDocument(
        canvas: const DesignCanvas(),
        elements: const [
          DesignElement(
            id: 'shape',
            type: DesignElementType.rectangle,
            x: 0,
            y: 0,
            width: 85.6,
            height: 10,
            style: {'fill_color': '#242C61'},
          ),
          DesignElement(
            id: 'name',
            type: DesignElementType.boundText,
            x: 5,
            y: 3,
            width: 40,
            height: 5,
            rotation: 3,
            zIndex: 1,
            style: {
              'font_size': 3.0,
              'font_weight': 700,
              'alignment': 'left',
              'color': '#FFFFFF',
            },
            data: {'field': 'full_name'},
          ),
          DesignElement(
            id: 'house',
            type: DesignElementType.customFieldText,
            x: 5,
            y: 15,
            width: 30,
            height: 5,
            zIndex: 2,
            style: {'font_size': 3.0, 'color': '#111111'},
            data: {'field_uuid': '11111111-1111-1111-1111-111111111111'},
          ),
          DesignElement(
            id: 'photo',
            type: DesignElementType.studentPhoto,
            x: 60,
            y: 15,
            width: 18,
            height: 22,
            zIndex: 3,
          ),
          DesignElement(
            id: 'logo',
            type: DesignElementType.schoolLogo,
            x: 40,
            y: 15,
            width: 12,
            height: 12,
            zIndex: 4,
          ),
          DesignElement(
            id: 'line',
            type: DesignElementType.line,
            x: 5,
            y: 45,
            width: 75,
            height: 1,
            zIndex: 5,
            style: {'color': '#242C61', 'border_width': 0.5},
          ),
        ],
      ),
    );

    final bytes = await PdfService.generateStudentCards(
      cards: cards,
      schoolName: 'Test School',
      template: template,
      schoolLogoUrl: 'not-a-valid-url',
    );
    final source = latin1.decode(bytes, allowInvalid: true);
    expect(
      RegExp(r'/Type\s*/Page(?!s)\b').allMatches(source).length,
      cards.length,
    );
  });
}
