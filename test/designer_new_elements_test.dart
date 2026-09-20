import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_bindings.dart';
import 'package:idcard_flutter/models/design_render_scene.dart';
import 'package:idcard_flutter/models/school_profile.dart';
import 'package:idcard_flutter/services/design_fonts.dart';
import 'package:idcard_flutter/services/pdf_document_renderer.dart';
import 'package:idcard_flutter/widgets/design_document_view.dart';
import 'designer_interactions_test.dart' as h;

const student = ApiStudent(
  uuid: 'student',
  sessionUuid: 's',
  classUuid: 'c',
  sectionUuid: 'x',
  admissionNo: 'A1',
  fullName: 'Student',
  bloodGroup: 'B+',
  isActive: true,
);
const school = SchoolProfile(
  uuid: 'school',
  schoolCode: 'SC',
  schoolName: 'School',
  principalSignatureUrl: 'https://example.org/signature.png',
  isActive: true,
);
const kinds = [
  DesignElementType.roundedRectangle,
  DesignElementType.ellipse,
  DesignElementType.circle,
  DesignElementType.triangle,
  DesignElementType.bloodDrop,
  DesignElementType.principalSignature,
];
DesignDocument document() => DesignDocument(
  canvas: const DesignCanvas(width: 90, height: 60),
  elements: [
    for (var i = 0; i < kinds.length; i++)
      DesignElement(
        id: 'new-$i',
        type: kinds[i],
        x: 2 + i * 12,
        y: 5,
        width: 10,
        height: 12,
        style: const {
          'fill_color': '#C62828',
          'border_color': '#112233',
          'border_width': .3,
          'corner_radius': 2,
          'fit': 'contain',
          'image_shape': 'oval',
        },
        data: kinds[i] == DesignElementType.bloodDrop
            ? const {'field': 'blood_group', 'fallback': 'BG'}
            : const {},
      ),
  ],
);

void main() {
  test('new elements round-trip and bind through the shared scene', () {
    final restored = DesignDocument.fromJson(document().toJson());
    expect(restored.elements.map((e) => e.type), kinds);
    final scene = DesignRenderScene(
      document: restored,
      bindings: const DesignBindings(student: student, schoolProfile: school),
    );
    expect(scene.elements[4].text, 'B+');
    expect(scene.elements[5].imageUrl, school.principalSignatureUrl);
    expect(scene.elements[5].style.fit, BoxFit.contain);
    final missing = DesignRenderScene(
      document: restored,
      bindings: const DesignBindings(student: student),
    );
    expect(missing.elements[5].imageUrl, isNull);
  });

  testWidgets('panels start hidden and open from their icon controls', (
    t,
  ) async {
    await h.mount(t, openPanels: false);
    expect(find.byKey(const Key('layer-a')), findsNothing);
    expect(find.byKey(const Key('property-x')), findsNothing);
    await t.tap(find.byKey(const Key('toggle-layers')));
    await t.tap(find.byKey(const Key('toggle-properties')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('layer-a')), findsOneWidget);
    await h.select(t);
    expect(find.byKey(const Key('property-x')), findsOneWidget);
    await t.tap(find.byKey(const Key('toggle-properties')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('property-x')), findsNothing);
    expect(find.byTooltip('Photo'), findsOneWidget);
  });

  testWidgets('tools create dedicated media and editable shapes', (t) async {
    await h.mount(t);
    for (final entry in <String, DesignElementType>{
      'add-principal-signature': DesignElementType.principalSignature,
      'add-blood-drop': DesignElementType.bloodDrop,
      'add-rounded-rectangle': DesignElementType.roundedRectangle,
      'add-ellipse': DesignElementType.ellipse,
      'add-circle': DesignElementType.circle,
      'add-triangle': DesignElementType.triangle,
    }.entries) {
      t.widget<IconButton>(find.byKey(Key(entry.key))).onPressed!();
      await t.pump();
      expect(h.view(t).document.elements.last.type, entry.value);
    }
    final elements = h.view(t).document.elements;
    expect(
      elements
          .firstWhere((e) => e.type == DesignElementType.principalSignature)
          .style['fit'],
      'contain',
    );
    expect(
      elements
          .firstWhere((e) => e.type == DesignElementType.bloodDrop)
          .data['field'],
      'blood_group',
    );
  });

  testWidgets('Flutter and PDF render vector shapes and missing signature', (
    t,
  ) async {
    final doc = document();
    final scene = DesignRenderScene(
      document: doc,
      bindings: const DesignBindings(student: student),
    );
    await t.binding.setSurfaceSize(const Size(900, 600));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      MaterialApp(
        home: DesignDocumentView(document: doc, student: student),
      ),
    );
    expect(find.text('B+'), findsOneWidget);
    expect(find.byIcon(Icons.draw_outlined), findsOneWidget);
    final fonts = (await t.runAsync(() => DesignFonts.pdfFonts()))!;
    final pdf = pw.Document(compress: false);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(90 * PdfPageFormat.mm, 60 * PdfPageFormat.mm),
        margin: pw.EdgeInsets.zero,
        build: (_) => PdfDocumentRenderer(fonts, const {}).build(scene),
      ),
    );
    final bytes = (await t.runAsync(() => pdf.save()))!;
    expect(bytes.length, greaterThan(1000));
  });
}
