import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_bindings.dart';
import 'package:idcard_flutter/models/design_render_scene.dart';
import 'package:idcard_flutter/widgets/design_document_view.dart';

const _student = ApiStudent(
  uuid: 'student',
  sessionUuid: 'session',
  classUuid: 'class',
  sectionUuid: 'section',
  admissionNo: 'ADM-001',
  fullName: 'Test Student',
  photoPath: null,
  isActive: true,
);

DesignElement _imageElement(
  String id,
  DesignElementType type, {
  String imageShape = 'rounded',
}) {
  return DesignElement(
    id: id,
    type: type,
    x: 5,
    y: 5,
    width: 20,
    height: 15,
    style: {'image_shape': imageShape, 'fit': 'contain', 'border_width': 0.0},
  );
}

DesignDocument _documentWithSignature({String imageShape = 'rounded'}) {
  return DesignDocument(
    canvas: const DesignCanvas(
      width: 53.98,
      height: 85.6,
      backgroundColor: '#FFFFFF',
    ),
    elements: [
      _imageElement(
        'signature',
        DesignElementType.principalSignature,
        imageShape: imageShape,
      ),
    ],
  );
}

Container _imageContainer(WidgetTester tester, Finder elementFinder) {
  return tester
      .widgetList<Container>(
        find.descendant(of: elementFinder, matching: find.byType(Container)),
      )
      .firstWhere((container) => container.clipBehavior == Clip.antiAlias);
}

void main() {
  group('Principal signature transparency', () {
    test('principal signature uses a transparent image background', () {
      final signatureStyle = DesignRenderStyle(
        _imageElement('signature', DesignElementType.principalSignature),
      );

      expect(signatureStyle.imageBackground, Colors.transparent);
    });

    test(
      'student photos and school logos retain the neutral image background',
      () {
        final photoStyle = DesignRenderStyle(
          _imageElement('photo', DesignElementType.studentPhoto),
        );

        final logoStyle = DesignRenderStyle(
          _imageElement('logo', DesignElementType.schoolLogo),
        );

        expect(
          photoStyle.imageBackground,
          DesignRenderStyle.defaultImageBackground,
        );

        expect(
          logoStyle.imageBackground,
          DesignRenderStyle.defaultImageBackground,
        );

        expect(
          DesignRenderStyle.defaultImageBackground,
          const Color(0xffeef1f5),
        );
      },
    );

    test(
      'render scene preserves transparent principal signature background',
      () {
        final document = _documentWithSignature();

        final scene = DesignRenderScene(
          document: document,
          bindings: const DesignBindings(student: _student),
        );

        final signature = scene.elements.single;

        expect(signature.element.type, DesignElementType.principalSignature);

        expect(signature.style.imageBackground, Colors.transparent);
      },
    );

    testWidgets(
      'rounded principal signature renders with a transparent container',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 300,
                height: 480,
                child: DesignDocumentView(
                  document: _documentWithSignature(),
                  student: _student,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final signatureFinder = find.byKey(
          const Key('design-element-signature'),
        );

        expect(signatureFinder, findsOneWidget);

        final container = _imageContainer(tester, signatureFinder);

        expect(container.decoration, isA<BoxDecoration>());

        final decoration = container.decoration! as BoxDecoration;

        expect(decoration.color, Colors.transparent);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'oval principal signature renders with a transparent container',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 300,
                height: 480,
                child: DesignDocumentView(
                  document: _documentWithSignature(imageShape: 'oval'),
                  student: _student,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final signatureFinder = find.byKey(
          const Key('design-element-signature'),
        );

        expect(signatureFinder, findsOneWidget);

        final container = _imageContainer(tester, signatureFinder);

        expect(container.decoration, isA<ShapeDecoration>());

        final decoration = container.decoration! as ShapeDecoration;

        expect(decoration.color, Colors.transparent);

        expect(tester.takeException(), isNull);
      },
    );
  });
}
