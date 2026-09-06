import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_render_scene.dart';
import 'package:idcard_flutter/models/design_text_layout.dart';
import 'package:idcard_flutter/services/design_fonts.dart';
import 'package:idcard_flutter/services/pdf_document_renderer.dart';
import 'pdf_fidelity_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<int, pw.Font> fonts;
  setUpAll(() async {
    fonts = await DesignFonts.pdfFonts();
  });

  Future<String> export(pw.Widget widget) async {
    final pdf = pw.Document(compress: false);
    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(100, 100),
        margin: pw.EdgeInsets.zero,
        build: (_) => widget,
      ),
    );
    return latin1.decode(await pdf.save());
  }

  test(
    'translucent RGB is opaque; each paint uses its one alpha state',
    () async {
      const translucent = Color(0x80336699);
      expect(PdfDocumentRenderer.color(translucent).alpha, 1);
      final doc = DesignDocument(
        canvas: const DesignCanvas(
          width: 20,
          height: 20,
          backgroundColor: '#80336699',
        ),
        elements: [
          for (final type in [
            DesignElementType.rectangle,
            DesignElementType.line,
            DesignElementType.text,
          ])
            DesignElement(
              id: type.name,
              type: type,
              x: 0,
              y: 0,
              width: 10,
              height: 10,
              data: const {'text': 'Café'},
              style: const {
                'color': '#80336699',
                'fill_color': '#80336699',
                'border_color': '#80336699',
                'border_width': 1,
              },
            ),
        ],
      );
      final source = await export(
        PdfDocumentRenderer(
          fonts,
          {},
        ).build(DesignRenderScene(document: doc, bindings: fixture.bindings)),
      );
      final alpha = RegExp(
        r'/ca\s+([\d.]+)',
      ).allMatches(source).map((m) => double.parse(m[1]!)).toList();
      expect(alpha, contains(closeTo(128 / 255, .00001)));
      expect(
        alpha.every((a) => (a - 128 / 255).abs() < .00001 || a == 1),
        true,
      );
      expect(source, contains('f*')); // Inside border ring, no centered stroke.
    },
  );

  for (final type in [
    DesignElementType.studentPhoto,
    DesignElementType.schoolLogo,
  ]) {
    for (final fit in ['contain', 'cover']) {
      test(
        '${type.name} $fit matches Flutter border padding and keeps bounds',
        () async {
          final memory = pw.MemoryImage(
            img.encodePng(img.Image(width: 60, height: 30)),
          );
          final element = DesignElement(
            id: 'image',
            type: type,
            x: 0,
            y: 0,
            width: 20,
            height: 15,
            style: {
              'fit': fit,
              'border_width': 1,
              'border_color': '#80336699',
              'corner_radius': 2,
            },
          );
          final node = DesignRenderElement(element, '', 'image');
          final outer =
              PdfDocumentRenderer(fonts, {'image': memory}).element(node)
                  as pw.ClipRRect;
          final stack = outer.child! as pw.Stack;
          final content =
              (stack.children[1] as pw.Positioned).child! as pw.Padding;
          final center = content.child! as pw.Center;
          final image = center.child! as pw.Image;
          await export(
            pw.SizedBox(
              width: PdfDocumentRenderer.mm(20),
              height: PdfDocumentRenderer.mm(15),
              child: outer,
            ),
          );
          expect(outer.box!.width, closeTo(PdfDocumentRenderer.mm(20), .001));
          expect(outer.box!.height, closeTo(PdfDocumentRenderer.mm(15), .001));
          expect(image.box!.width, closeTo(PdfDocumentRenderer.mm(18), .001));
          expect(
            image.box!.height,
            closeTo(PdfDocumentRenderer.mm(fit == 'contain' ? 9 : 13), .001),
          );
          expect(
            image.box!.bottom,
            closeTo(PdfDocumentRenderer.mm(fit == 'contain' ? 2 : 0), .001),
          );
          expect(
            image.fit,
            fit == 'contain' ? pw.BoxFit.contain : pw.BoxFit.cover,
          );
          expect(outer.horizontalRadius, PdfDocumentRenderer.mm(2));
          final border =
              (stack.children.last as pw.Positioned).child! as pw.Opacity;
          expect(border.opacity, closeTo(128 / 255, .00001));
          expect(border.child, isA<pw.CustomPaint>());
        },
      );
    }
  }

  test(
    'background cover and failed image retain all three page geometries',
    () async {
      final image = pw.MemoryImage(
        img.encodePng(img.Image(width: 60, height: 30)),
      );
      for (final size in [
        const Size(53.98, 85.60),
        const Size(85.60, 53.98),
        const Size(100, 100),
      ]) {
        final scene = DesignRenderScene(
          document: fixture.fixture(size.width, size.height),
          bindings: fixture.bindings,
          assetBaseUrl: 'https://school.test/',
        );
        for (final available in [true, false]) {
          final root =
              PdfDocumentRenderer(fonts, {
                    'https://school.test/background.png': available
                        ? image
                        : null,
                  }).build(scene)
                  as pw.SizedBox;
          expect(root.width, PdfDocumentRenderer.mm(size.width));
          expect(root.height, PdfDocumentRenderer.mm(size.height));
          final stack = (root.child! as pw.ClipRect).child! as pw.Stack;
          final backgrounds = stack.children
              .whereType<pw.Positioned>()
              .map((p) => p.child)
              .whereType<pw.Image>()
              .toList();
          expect(backgrounds.length, available ? 1 : 0);
          if (available) expect(backgrounds.single.fit, pw.BoxFit.cover);
          final pdf = pw.Document(compress: false);
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(root.width!, root.height!),
              margin: pw.EdgeInsets.zero,
              build: (_) => root,
            ),
          );
          expect(await pdf.save(), isNotEmpty);
        }
      }
    },
  );

  test(
    'all nine bundled weights export Latin with multiline maxLines',
    () async {
      expect(fonts.keys, orderedEquals(List.generate(9, (i) => (i + 1) * 100)));
      for (final weight in fonts.keys) {
        final e = DesignElement(
          id: 'text',
          type: DesignElementType.text,
          x: 0,
          y: 0,
          width: 20,
          height: 10,
          style: {'font_weight': weight, 'max_lines': 2, 'font_size': 3},
        );
        final node = DesignRenderElement(
          e,
          'Élodie – “Café”\nSão Paulo\nHidden',
          null,
        );
        final lines = layoutDesignText(node);
        expect(lines.length, 2);
        expect(lines.map((l) => l.text).join(), isNot(contains('Hidden')));
        final source = await export(
          pw.SizedBox(
            width: PdfDocumentRenderer.mm(20),
            height: PdfDocumentRenderer.mm(10),
            child: PdfDocumentRenderer(fonts, {}).element(node),
          ),
        );
        expect(source, contains('/FontFile2'));
        expect(source, contains('/ToUnicode'));
      }
    },
  );
}
