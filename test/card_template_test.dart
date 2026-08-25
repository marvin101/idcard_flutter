import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/widgets/template_card.dart';

void main() {
  test('uploaded design survives an API round trip', () {
    final source = CardTemplate.uploadedDesign;
    final decoded = CardTemplate.fromApi(source.toApi());

    expect(decoded.schoolTitle, source.schoolTitle);
    expect(decoded.primaryColor, source.primaryColor);
    expect(decoded.maskAadhaar, isTrue);
  });

  test('Aadhaar masking keeps only the final four digits visible', () {
    expect(maskAadhaarValue('2162 3230 1889'), 'XXXXXXXX1889');
  });

  testWidgets('card details do not overflow at grid widths', (tester) async {
    final student = ApiStudent(
      uuid: 'test',
      sessionUuid: 'session',
      classUuid: 'class',
      sectionUuid: 'section',
      admissionNo: 'COM/52',
      stream: 'SCIENCE',
      fullName: 'A deliberately long student name for layout testing',
      fatherName: 'A deliberately long father name',
      motherName: 'A deliberately long mother name',
      dob: DateTime(2010, 1, 1),
      bloodGroup: 'O+',
      mobile: '9999999999',
      aadhaar: '123456789012',
      address: 'A deliberately long postal address used to test card sizing',
      isActive: true,
    );

    for (final width in [180.0, 250.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: width,
              child: TemplateCard(
                student: student,
                template: CardTemplate.uploadedDesign,
                sessionName: '2026-2028',
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
