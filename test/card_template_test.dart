import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/id_card_preview.dart';
import 'package:idcard_flutter/widgets/template_card.dart';

void main() {
  test('uploaded design survives an API round trip', () {
    final source = CardTemplate.uploadedDesign;
    final decoded = CardTemplate.fromApi(source.toApi());

    expect(decoded.schoolTitle, source.schoolTitle);
    expect(decoded.primaryColor, source.primaryColor);
    expect(decoded.maskAadhaar, isTrue);
    expect(decoded.document.schemaVersion, 2);
    expect(decoded.toApi()['design']['schema_version'], 2);
  });

  test('optional back design survives an API round trip', () {
    final source = CardTemplate(
      name: 'Duplex',
      document: const DesignDocument(canvas: DesignCanvas(), elements: []),
      backDocument: const DesignDocument(
        canvas: DesignCanvas(backgroundColor: '#EEEEEE'),
        elements: [
          DesignElement(
            id: 'back-label',
            type: DesignElementType.text,
            x: 5,
            y: 5,
            width: 30,
            height: 8,
            data: {'text': 'BACK'},
          ),
        ],
      ),
    );

    final decoded = CardTemplate.fromApi(source.toApi());
    expect(decoded.hasBackDesign, isTrue);
    expect(decoded.backDocument!.elements.single.data['text'], 'BACK');
    expect(decoded.toApi()['back_design'], isA<Map<String, dynamic>>());
  });

  test('front and back canvas dimensions must match', () {
    final payload = CardTemplate(
      name: 'Mismatched',
      document: const DesignDocument(canvas: DesignCanvas(), elements: []),
      backDocument: const DesignDocument(
        canvas: DesignCanvas(width: 90),
        elements: [],
      ),
    ).toApi();

    expect(() => CardTemplate.fromApi(payload), throwsFormatException);
  });

  test('legacy v1 settings normalize deterministically to v2 elements', () {
    final template = CardTemplate.fromApi({
      'name': 'Legacy',
      'design': {
        'version': 1,
        'school_title': 'Legacy School',
        'primary_color': '#123456',
      },
    });

    expect(template.schoolTitle, 'Legacy School');
    expect(template.document.canvas.width, 85.6);
    expect(template.document.elements, isNotEmpty);
    expect(template.document.settings['migrated_from_v1'], isTrue);
    expect(template.toApi()['design']['schema_version'], 2);
  });

  test('explicit unsupported schema versions are not treated as legacy', () {
    expect(
      () => CardTemplate.fromApi({
        'name': 'Future',
        'design': {'schema_version': 3},
      }),
      throwsFormatException,
    );
  });

  test('v2 documents require canvas and elements instead of defaulting', () {
    for (final design in [
      {'schema_version': 2, 'elements': <dynamic>[]},
      {
        'schema_version': 2,
        'canvas': {'width': 85.6, 'height': 53.98},
      },
    ]) {
      expect(
        () => CardTemplate.fromApi({'name': 'Corrupt', 'design': design}),
        throwsFormatException,
      );
    }
  });

  test('invalid v2 server field types are rejected', () {
    expect(
      () => CardTemplate.fromApi({
        'name': 'Corrupt',
        'design': {
          'schema_version': 2,
          'canvas': {'width': '85.6', 'height': 53.98},
          'elements': <dynamic>[],
        },
      }),
      throwsFormatException,
    );
    expect(
      () => CardTemplate.fromApi({
        'name': 'Corrupt',
        'design': {
          'schema_version': 2,
          'canvas': {'width': 85.6, 'height': 53.98},
          'elements': [
            {
              'id': 'bad',
              'type': 'future_element',
              'x': 1,
              'y': 1,
              'width': 10,
              'height': 10,
              'rotation': 0,
              'z_index': 0,
              'locked': false,
              'visible': true,
            },
          ],
        },
      }),
      throwsFormatException,
    );
  });

  test('explicit schema version 1 remains legacy compatible', () {
    final template = CardTemplate.fromApi({
      'name': 'Legacy',
      'design': {'schema_version': 1, 'school_title': 'Legacy School'},
    });

    expect(template.schoolTitle, 'Legacy School');
    expect(template.document.settings['migrated_from_v1'], isTrue);
  });

  test('v2 geometry and custom UUID bindings survive serialization', () {
    final source = CardTemplate(
      name: 'V2',
      document: DesignDocument(
        canvas: const DesignCanvas(),
        elements: const [
          DesignElement(
            id: 'house',
            type: DesignElementType.customFieldText,
            x: 4,
            y: 5,
            width: 20,
            height: 4,
            rotation: 12,
            data: {'field_uuid': '11111111-1111-1111-1111-111111111111'},
          ),
        ],
      ),
    );
    final decoded = CardTemplate.fromApi(source.toApi());
    expect(decoded.document.elements.single.rotation, 12);
    expect(
      decoded.document.elements.single.data['field_uuid'],
      '11111111-1111-1111-1111-111111111111',
    );
  });

  test('QR elements preserve their data and rendering options', () {
    const element = DesignElement(
      id: 'qr',
      type: DesignElementType.qrCode,
      x: 4,
      y: 5,
      width: 20,
      height: 20,
      data: {'field': 'admission_no', 'prefix': 'ID:'},
      style: {
        'color': '#112233',
        'background_color': '#FFFFFF',
        'quiet_zone': 2,
        'error_correction': 'high',
      },
    );
    final source = CardTemplate(
      name: 'QR',
      document: const DesignDocument(
        canvas: DesignCanvas(),
        elements: [element],
      ),
    );

    final decoded = CardTemplate.fromApi(source.toApi());
    final qr = decoded.document.elements.single;
    expect(qr.type, DesignElementType.qrCode);
    expect(qr.data, element.data);
    expect(qr.style, element.style);
    expect(qr.toJson()['type'], 'qr_code');
  });

  test(
    'custom canvas dimensions reload with orientation derived from size',
    () {
      final template = CardTemplate.fromApi({
        'name': 'Portrait pass',
        'design': {
          'schema_version': 2,
          'canvas': {
            'width': 70.0,
            'height': 100.0,
            'orientation': 'landscape',
            'background_color': '#ABCDEF',
          },
          'elements': <dynamic>[],
          'settings': <String, dynamic>{},
        },
      });

      expect(template.document.canvas.width, 70);
      expect(template.document.canvas.height, 100);
      expect(template.document.canvas.orientation, 'portrait');
      expect(template.toApi()['design']['canvas']['orientation'], 'portrait');
    },
  );

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

  testWidgets('two-sided card preview can flip between front and back', (
    tester,
  ) async {
    final api = ApiService(baseUrl: 'http://test');
    addTearDown(api.dispose);
    final student = ApiStudent(
      uuid: 'duplex-student',
      sessionUuid: 'session',
      classUuid: 'class',
      sectionUuid: 'section',
      admissionNo: 'A-1',
      fullName: 'Student',
      isActive: true,
    );
    DesignDocument side(String label) => DesignDocument(
      canvas: const DesignCanvas(),
      elements: [
        DesignElement(
          id: label,
          type: DesignElementType.text,
          x: 5,
          y: 5,
          width: 30,
          height: 8,
          data: {'text': label},
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            child: IdCardPreview(
              student: student,
              schoolName: 'School',
              api: api,
              template: CardTemplate(
                name: 'Duplex',
                document: side('FRONT SIDE'),
                backDocument: side('BACK SIDE'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('FRONT SIDE'), findsOneWidget);
    expect(find.text('BACK SIDE'), findsNothing);
    await tester.tap(
      find.byKey(const Key('preview-side-toggle-duplex-student')),
    );
    await tester.pump();
    expect(find.text('FRONT SIDE'), findsNothing);
    expect(find.text('BACK SIDE'), findsOneWidget);
  });
}
