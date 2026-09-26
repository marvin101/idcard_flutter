import 'dart:math' as math;

import 'package:flutter/material.dart' show BoxFit, Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/card_template.dart';
import '../models/design_barcode.dart';
import '../models/design_render_scene.dart';
import '../models/design_qr.dart';
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
                child: pw.ClipRect(
                  child: pw.Opacity(
                    opacity: scene.backgroundOpacity,
                    child: pw.Transform.translate(
                      offset: PdfPoint(
                        mm(scene.backgroundOffsetX),
                        mm(scene.backgroundOffsetY),
                      ),
                      child: pw.Transform.scale(
                        scale: scene.backgroundScale,
                        child: pw.Image(background, fit: pw.BoxFit.cover),
                      ),
                    ),
                  ),
                ),
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

  pw.Widget _box(
    DesignRenderStyle style,
    Color fill, {
    required double radius,
    pw.Widget? child,
  }) {
    return pw.Stack(
      children: [
        if (fill.a > 0)
          pw.Positioned.fill(
            child: pw.Opacity(
              opacity: fill.a,
              child: pw.DecoratedBox(
                decoration: pw.BoxDecoration(
                  color: color(fill),
                  borderRadius: pw.BorderRadius.circular(mm(radius)),
                ),
              ),
            ),
          ),

        if (child != null)
          pw.Positioned.fill(
            // Match Container.decoration.padding in DesignDocumentView.
            // The border is painted last, independently of content layout.
            child: pw.Padding(
              padding: pw.EdgeInsets.all(mm(style.borderWidth)),
              child: pw.Center(child: child),
            ),
          ),

        if (style.borderWidth > 0 && style.border.a > 0)
          pw.Positioned.fill(
            child: pw.Opacity(
              opacity: style.border.a,
              // Flutter paints an inside border. PDF's BoxBorder strokes are
              // centered on the edge, losing half their width when clipped.
              child: pw.CustomPaint(
                painter: (canvas, size) {
                  final outerRadius = mm(radius);
                  final width = mm(style.borderWidth);
                  canvas.setFillColor(color(style.border));
                  canvas.drawRRect(
                    0,
                    0,
                    size.x,
                    size.y,
                    outerRadius,
                    outerRadius,
                  );
                  if (size.x > 2 * width && size.y > 2 * width) {
                    final innerRadius = math.max(0.0, outerRadius - width);
                    canvas.drawRRect(
                      width,
                      width,
                      size.x - 2 * width,
                      size.y - 2 * width,
                      innerRadius,
                      innerRadius,
                    );
                  }
                  canvas.fillPath(evenOdd: true);
                },
              ),
            ),
          ),
      ],
    );
  }

  pw.Widget element(DesignRenderElement node) {
    final style = node.style;
    final radius = math.min(
      style.radius,
      math.min(node.element.width, node.element.height) / 2,
    );

    switch (node.element.type) {
      case DesignElementType.rectangle:
        return _box(style, style.fill, radius: radius);

      case DesignElementType.roundedRectangle:
        return _box(style, style.fill, radius: radius);

      case DesignElementType.ellipse:
      case DesignElementType.circle:
      case DesignElementType.triangle:
      case DesignElementType.bloodDrop:
        return pw.CustomPaint(
          painter: (canvas, size) {
            final stroke = mm(style.borderWidth);
            void drawPath() {
              if (node.element.type == DesignElementType.ellipse ||
                  node.element.type == DesignElementType.circle) {
                canvas.drawEllipse(
                  size.x / 2,
                  size.y / 2,
                  math.max(0, size.x / 2 - stroke / 2),
                  math.max(0, size.y / 2 - stroke / 2),
                );
              } else if (node.element.type == DesignElementType.triangle) {
                canvas.moveTo(size.x / 2, size.y);
                canvas.lineTo(size.x, 0);
                canvas.lineTo(0, 0);
              } else {
                canvas.moveTo(size.x / 2, size.y);
                canvas.curveTo(
                  size.x * .14,
                  size.y * .66,
                  0,
                  size.y * .47,
                  0,
                  size.y * .31,
                );
                canvas.curveTo(0, 0, size.x, 0, size.x, size.y * .31);
                canvas.curveTo(
                  size.x,
                  size.y * .47,
                  size.x * .86,
                  size.y * .66,
                  size.x / 2,
                  size.y,
                );
              }
            }

            if (style.fill.a > 0) {
              canvas.setGraphicState(PdfGraphicState(opacity: style.fill.a));
              canvas.setFillColor(color(style.fill));
              drawPath();
              canvas.fillPath();
            }
            if (stroke > 0 && style.border.a > 0) {
              canvas.setGraphicState(PdfGraphicState(opacity: style.border.a));
              canvas.setStrokeColor(color(style.border));
              canvas.setLineWidth(stroke);
              drawPath();
              canvas.strokePath(close: true);
            }
          },
          child: pw.SizedBox(
            width: mm(node.element.width),
            height: mm(node.element.height),
            child: node.element.type == DesignElementType.bloodDrop
                ? pw.Center(
                    child: pw.Text(
                      node.text,
                      style: pw.TextStyle(
                        font: fonts[700],
                        fontSize: mm(3.2),
                        color: PdfColors.white,
                      ),
                    ),
                  )
                : pw.SizedBox(),
          ),
        );

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
      case DesignElementType.principalSignature:
        final image = images[node.imageUrl];
        final imageContentWidth = math.max(
          0.0,
          node.element.width - (style.borderWidth * 2),
        );
        final imageContentHeight = math.max(
          0.0,
          node.element.height - (style.borderWidth * 2),
        );

        if (style.imageShape == 'oval') {
          return pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.ClipOval(
                  child: pw.Container(
                    color: color(style.imageBackground),
                    padding: pw.EdgeInsets.all(mm(style.borderWidth)),
                    alignment: pw.Alignment.center,
                    child: image == null
                        ? pw.Center(
                            child: pw.Text(
                              node.element.type ==
                                      DesignElementType.studentPhoto
                                  ? 'PHOTO'
                                  : node.element.type ==
                                        DesignElementType.principalSignature
                                  ? 'SIGNATURE'
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
                ),
              ),
              if (style.borderWidth > 0 && style.border.a > 0)
                pw.Positioned.fill(
                  child: pw.Opacity(
                    opacity: style.border.a,
                    child: pw.CustomPaint(
                      painter: (canvas, size) {
                        canvas.setStrokeColor(color(style.border));
                        canvas.setLineWidth(mm(style.borderWidth));
                        canvas.drawEllipse(
                          size.x / 2,
                          size.y / 2,
                          math.max(0, size.x / 2 - mm(style.borderWidth) / 2),
                          math.max(0, size.y / 2 - mm(style.borderWidth) / 2),
                        );
                        canvas.strokePath();
                      },
                    ),
                  ),
                ),
            ],
          );
        }
        final imageRadius = style.imageShape == 'rounded' ? radius : 0.0;
        return pw.ClipRRect(
          horizontalRadius: mm(imageRadius),
          verticalRadius: mm(imageRadius),
          child: _box(
            style,
            style.imageBackground,
            radius: imageRadius,
            child: image == null
                ? pw.Center(
                    child: pw.Text(
                      node.element.type == DesignElementType.studentPhoto
                          ? 'PHOTO'
                          : node.element.type ==
                                DesignElementType.principalSignature
                          ? 'SIGNATURE'
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
                    width: mm(imageContentWidth),
                    height: mm(imageContentHeight),
                    fit: style.fit == BoxFit.contain
                        ? pw.BoxFit.contain
                        : pw.BoxFit.cover,
                  ),
          ),
        );

      case DesignElementType.qrCode:
        if (!isDesignQrDataSupported(node.text)) {
          return pw.Container(color: color(style.qrBackground));
        }
        return pw.BarcodeWidget(
          data: node.text,
          barcode: designQrBarcode(style.errorCorrection),
          color: color(style.color),
          backgroundColor: color(style.qrBackground),
          padding: pw.EdgeInsets.all(mm(style.quietZone)),
          drawText: false,
        );

      case DesignElementType.barcode:
        final symbology =
            node.element.data['symbology'] as String? ?? 'code128';
        if (!isDesignBarcodeDataSupported(node.text, symbology)) {
          return pw.Container(color: color(style.qrBackground));
        }
        return pw.BarcodeWidget(
          data: node.text,
          barcode: designBarcode(symbology),
          color: color(style.color),
          backgroundColor: color(style.qrBackground),
          padding: pw.EdgeInsets.all(mm(style.quietZone)),
          drawText: style.showText && !isDesignBarcodeSquare(symbology),
          textStyle: pw.TextStyle(
            font: fonts[400],
            fontSize: mm(style.fontSize),
            color: color(style.color),
          ),
          textPadding: mm(.5),
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
