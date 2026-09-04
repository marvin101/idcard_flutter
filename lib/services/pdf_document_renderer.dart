import 'package:flutter/material.dart' show BoxFit, Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/card_template.dart';
import '../models/design_render_scene.dart';
import '../models/design_text_layout.dart';
import 'design_fonts.dart';

/// Vector PDF adapter.
///
/// DesignDocument interpretation, bindings, and text layout are resolved
/// before this layer. This renderer should only translate the normalized
/// render scene from document millimetres into PDF points and paint it.
class PdfDocumentRenderer {
  const PdfDocumentRenderer(this.fonts, this.images);

  final Map<int, pw.Font> fonts;
  final Map<String, pw.MemoryImage?> images;

  /// Convert document millimetres to PDF points.
  static double mm(double value) => value * PdfPageFormat.mm;

  /// Convert only RGB here.
  ///
  /// Alpha is deliberately handled separately through PDF graphic opacity.
  /// Including alpha in PdfColor *and* wrapping the widget in pw.Opacity
  /// would apply transparency twice.
  static PdfColor color(Color value) {
    return PdfColor(value.r, value.g, value.b);
  }

  /// Flutter's positive rotation direction and the PDF canvas coordinate
  /// system have opposite Y directions.
  static double rotation(DesignRenderElement node) => -node.radians;

  pw.Widget build(DesignRenderScene scene) {
    return pw.SizedBox(
      width: mm(scene.canvas.width),
      height: mm(scene.canvas.height),
      child: pw.ClipRect(
        child: pw.Stack(
          children: [
            pw.Positioned.fill(
              child: _withOpacity(
                scene.background.a,
                pw.Container(color: color(scene.background)),
              ),
            ),

            if (images[scene.backgroundImage]
                case final pw.MemoryImage background)
              pw.Positioned.fill(
                child: pw.Image(background, fit: pw.BoxFit.cover),
              ),

            for (final node in scene.elements)
              pw.Positioned(
                left: mm(node.element.x),
                top: mm(node.element.y),
                child: pw.Transform.rotate(
                  angle: rotation(node),
                  child: pw.SizedBox(
                    width: mm(node.element.width),
                    height: mm(node.element.height),
                    child: element(node),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  pw.Widget _withOpacity(double opacity, pw.Widget child) {
    if (opacity <= 0) {
      return pw.SizedBox();
    }

    if (opacity >= 1) {
      return child;
    }

    return pw.Opacity(opacity: opacity, child: child);
  }

  pw.Widget _box(DesignRenderStyle style, Color fill, {pw.Widget? child}) {
    return pw.Stack(
      children: [
        if (fill.a > 0)
          pw.Positioned.fill(
            child: pw.Opacity(
              opacity: fill.a,
              child: pw.DecoratedBox(
                decoration: pw.BoxDecoration(
                  color: color(fill),
                  borderRadius: pw.BorderRadius.circular(mm(style.radius)),
                ),
              ),
            ),
          ),

        if (child != null) pw.Positioned.fill(child: child),

        if (style.borderWidth > 0 && style.border.a > 0)
          pw.Positioned.fill(
            child: pw.Opacity(
              opacity: style.border.a,
              child: pw.DecoratedBox(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: color(style.border),
                    width: mm(style.borderWidth),
                  ),
                  borderRadius: pw.BorderRadius.circular(mm(style.radius)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  pw.Widget element(DesignRenderElement node) {
    final style = node.style;

    switch (node.element.type) {
      case DesignElementType.rectangle:
        return _box(style, style.fill);

      case DesignElementType.line:
        return pw.Center(
          child: _withOpacity(
            style.color.a,
            pw.Container(
              height: mm(style.borderWidth),
              color: color(style.color),
            ),
          ),
        );

      case DesignElementType.studentPhoto:
      case DesignElementType.schoolLogo:
        final image = images[node.imageUrl];

        return pw.ClipRRect(
          horizontalRadius: mm(style.radius),
          verticalRadius: mm(style.radius),
          child: _box(
            style,
            DesignRenderStyle.imageBackground,
            child: image == null
                ? pw.Center(
                    child: pw.Text(
                      node.element.type == DesignElementType.studentPhoto
                          ? 'PHOTO'
                          : 'LOGO',
                      style: pw.TextStyle(
                        font: fonts[400],
                        fontSize: mm(2),
                        color: PdfColors.grey,
                      ),
                    ),
                  )
                : pw.Image(
                    image,
                    fit: style.fit == BoxFit.contain
                        ? pw.BoxFit.contain
                        : pw.BoxFit.cover,
                  ),
          ),
        );

      case DesignElementType.text:
      case DesignElementType.boundText:
      case DesignElementType.customFieldText:
        DesignFonts.validatePdfText(node.text);

        final lines = layoutDesignText(node);

        return pw.ClipRect(
          child: pw.Builder(
            builder: (context) {
              final font = fonts[style.weight]?.getFont(context);

              if (font == null) {
                throw StateError(
                  'Missing PDF font for weight ${style.weight}.',
                );
              }

              return pw.CustomPaint(
                painter: (canvas, size) {
                  canvas.setGraphicState(
                    PdfGraphicState(opacity: style.color.a),
                  );

                  // Alpha is controlled by the graphic state above.
                  canvas.setFillColor(color(style.color));

                  for (final line in lines) {
                    canvas.drawString(
                      font,
                      mm(style.fontSize),
                      line.text,
                      mm(line.x),

                      // PDF uses a bottom-up Y coordinate while the normalized
                      // layout uses top-down document coordinates.
                      size.y - mm(line.baseline),
                    );
                  }
                },
              );
            },
          ),
        );
    }
  }
}
