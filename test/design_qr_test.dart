import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_bindings.dart';
import 'package:idcard_flutter/models/student_field.dart';
import 'package:idcard_flutter/widgets/design_qr_code.dart';

const _student = ApiStudent(
  uuid: 'student',
  sessionUuid: 'session',
  classUuid: 'class',
  sectionUuid: 'section',
  admissionNo: 'ADM-42',
  fullName: 'Asha Singh',
  isActive: true,
  customFields: [StudentCustomFieldValue(fieldUuid: 'house', value: 'Blue')],
);

void main() {
  test('QR bindings resolve static, system, and custom sources', () {
    const bindings = DesignBindings(student: _student);
    const staticQr = DesignElement(
      id: 'static',
      type: DesignElementType.qrCode,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      data: {'text': 'https://example.test/card'},
    );
    const systemQr = DesignElement(
      id: 'system',
      type: DesignElementType.qrCode,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      data: {'field': 'admission_no', 'prefix': 'ID:', 'suffix': ':END'},
    );
    const customQr = DesignElement(
      id: 'custom',
      type: DesignElementType.qrCode,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      data: {'field_uuid': 'house'},
    );

    expect(bindings.text(staticQr), 'https://example.test/card');
    expect(bindings.text(systemQr), 'ID:ADM-42:END');
    expect(bindings.text(customQr), 'Blue');
  });

  test('multi-field QR bindings produce scoped JSON and labeled text', () {
    const bindings = DesignBindings(
      student: _student,
      className: 'X',
      schoolName: 'Parity School',
    );
    const fields = [
      {'field': 'full_name', 'label': 'Full name'},
      {'field': 'admission_no', 'label': 'Admission number'},
      {'field': 'class', 'label': 'Class'},
      {'field_uuid': 'house', 'label': 'House'},
    ];
    const jsonQr = DesignElement(
      id: 'json',
      type: DesignElementType.qrCode,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      data: {'fields': fields, 'format': 'json'},
    );
    const textQr = DesignElement(
      id: 'text',
      type: DesignElementType.qrCode,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      data: {'fields': fields, 'format': 'labeled_text'},
    );

    expect(
      bindings.text(jsonQr),
      '{"full_name":"Asha Singh","admission_no":"ADM-42",'
      '"class":"X","custom:house":"Blue"}',
    );
    expect(
      bindings.text(textQr),
      'Full name: Asha Singh\nAdmission number: ADM-42\nClass: X\nHouse: Blue',
    );
  });

  testWidgets('QR widget paints valid data for every correction level', (
    tester,
  ) async {
    for (final level in ['low', 'medium', 'quartile', 'high']) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox.square(
              dimension: 160,
              child: DesignQrCode(
                data: 'ADM-42',
                color: Colors.black,
                backgroundColor: Colors.white,
                quietZone: 4,
                errorCorrection: level,
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('design-qr-code')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('oversized QR content has a stable unavailable state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DesignQrCode(
          data: List.filled(1001, 'x').join(),
          color: Colors.black,
          backgroundColor: Colors.white,
          quietZone: 1,
          errorCorrection: 'medium',
        ),
      ),
    );

    expect(find.byKey(const Key('design-qr-unavailable')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
