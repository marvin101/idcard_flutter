import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/bulk_card_export.dart';
import 'package:idcard_flutter/models/design_barcode.dart';
import 'package:idcard_flutter/models/design_bindings.dart';
import 'package:idcard_flutter/models/student_field.dart';
import 'package:idcard_flutter/services/pdf_service.dart';
import 'package:idcard_flutter/widgets/design_barcode.dart';

const _student = ApiStudent(
  uuid: 'student',
  sessionUuid: 'session',
  classUuid: 'class',
  sectionUuid: 'section',
  admissionNo: 'ADM-42',
  fullName: 'Asha Singh',
  isActive: true,
  customFields: [StudentCustomFieldValue(fieldUuid: 'house', value: 'BLUE')],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'barcode bindings resolve static, system, custom, and multiple fields',
    () {
      const bindings = DesignBindings(student: _student, className: 'X');
      const system = DesignElement(
        id: 'system',
        type: DesignElementType.barcode,
        x: 0,
        y: 0,
        width: 35,
        height: 15,
        data: {
          'symbology': 'code128',
          'field': 'admission_no',
          'prefix': 'ID:',
        },
      );
      const custom = DesignElement(
        id: 'custom',
        type: DesignElementType.barcode,
        x: 0,
        y: 0,
        width: 35,
        height: 15,
        data: {'symbology': 'code39', 'field_uuid': 'house'},
      );
      const multiple = DesignElement(
        id: 'multiple',
        type: DesignElementType.barcode,
        x: 0,
        y: 0,
        width: 35,
        height: 15,
        data: {
          'symbology': 'code128',
          'fields': [
            {'field': 'admission_no', 'label': 'Admission'},
            {'field': 'class', 'label': 'Class'},
          ],
          'format': 'labeled_text',
        },
      );

      expect(bindings.text(system), 'ID:ADM-42');
      expect(bindings.text(custom), 'BLUE');
      expect(bindings.text(multiple), 'Admission: ADM-42\nClass: X');
    },
  );

  test('supported formats enforce their own content rules', () {
    expect(designBarcodeValidation('ADM-42', 'code128'), isNull);
    expect(designBarcodeValidation('ADM-42', 'code39'), isNull);
    expect(designBarcodeValidation('5901234123457', 'ean13'), isNull);
    expect(designBarcodeValidation('Student: Asha', 'data_matrix'), isNull);
    expect(
      designBarcodeValidation('not-a-number', 'ean13'),
      contains('Invalid EAN-13'),
    );
    expect(
      designBarcodeValidation('lowercase', 'code39'),
      contains('Invalid Code 39'),
    );
  });

  testWidgets('barcode widget paints all supported formats', (tester) async {
    const samples = {
      'code128': 'ADM-42',
      'code39': 'ADM-42',
      'ean13': '5901234123457',
      'data_matrix': 'Student: Asha',
    };
    for (final entry in samples.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: entry.key == 'data_matrix' ? 160 : 260,
              height: 120,
              child: DesignBarcode(
                data: entry.value,
                symbology: entry.key,
                color: Colors.black,
                backgroundColor: Colors.white,
                quietZone: 4,
                showText: entry.key != 'data_matrix',
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('design-barcode')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('invalid barcode has a stable unavailable state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DesignBarcode(
          data: 'ABC',
          symbology: 'ean13',
          color: Colors.black,
          backgroundColor: Colors.white,
          quietZone: 1,
          showText: true,
          fontSize: 12,
        ),
      ),
    );

    expect(find.byKey(const Key('design-barcode-unavailable')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('bulk preflight blocks invalid resolved barcode content', () {
    const template = CardTemplate(
      name: 'EAN card',
      document: DesignDocument(
        canvas: DesignCanvas(width: 85.6, height: 53.98),
        elements: [
          DesignElement(
            id: 'ean',
            type: DesignElementType.barcode,
            x: 5,
            y: 5,
            width: 40,
            height: 12,
            data: {'symbology': 'ean13', 'field': 'admission_no'},
          ),
        ],
      ),
    );
    final inspection = BulkExportInspection.inspect(
      students: const [_student],
      template: template,
      schoolName: 'Barcode School',
      sessionName: (_) => null,
      className: (_) => null,
      sectionName: (_) => null,
    );

    expect(inspection.canContinue, isFalse);
    expect(
      inspection.blockingIssues.single.message,
      contains('Invalid EAN-13'),
    );
  });

  test('barcode document round-trips and renders in vector PDF', () async {
    const element = DesignElement(
      id: 'barcode',
      type: DesignElementType.barcode,
      x: 5,
      y: 5,
      width: 50,
      height: 16,
      style: {
        'color': '#000000',
        'background_color': '#FFFFFF',
        'quiet_zone': 1,
        'show_text': true,
        'font_size': 2.5,
      },
      data: {'symbology': 'code128', 'field': 'admission_no'},
    );
    const document = DesignDocument(
      canvas: DesignCanvas(width: 85.6, height: 53.98),
      elements: [element],
    );
    final restored = DesignDocument.fromJson(document.toJson());
    expect(restored.elements.single.type, DesignElementType.barcode);
    expect(restored.elements.single.toJson()['type'], 'barcode');

    final bytes = await PdfService.generateStudentCard(
      student: _student,
      schoolName: 'Barcode School',
      template: const CardTemplate(name: 'Barcode', document: document),
    );
    final source = latin1.decode(bytes, allowInvalid: true);
    expect(RegExp(r'/Type\s*/Page(?!s)\b').allMatches(source).length, 1);
  });
}
