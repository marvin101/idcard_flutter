import 'package:flutter/material.dart' show Color, BoxFit;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/card_template.dart';
import '../models/design_render_scene.dart';
import '../models/design_text_layout.dart';
import 'design_fonts.dart';

/// Vector PDF adapter. Interpretation/bindings and text layout are shared with
/// Flutter; this layer only converts millimetres to PDF points and paints.
class PdfDocumentRenderer {
  const PdfDocumentRenderer(this.fonts, this.images);
  final Map<int, pw.Font> fonts;
  final Map<String, pw.MemoryImage?> images;
  static double mm(double value) => value * PdfPageFormat.mm;
  static PdfColor color(Color value) =>
      PdfColor(value.r, value.g, value.b, value.a);
  static double rotation(DesignRenderElement node) => -node.radians;

  pw.Widget build(DesignRenderScene scene) => pw.SizedBox(
    width:mm(scene.canvas.width),height:mm(scene.canvas.height),
    child:pw.ClipRect(child:pw.Stack(children:[
      pw.Positioned.fill(child:pw.Opacity(opacity:scene.background.a,child:pw.Container(color:color(scene.background)))),
      if(images[scene.backgroundImage] case final pw.MemoryImage background)
        pw.Positioned.fill(child:pw.Image(background,fit:pw.BoxFit.cover)),
      for(final node in scene.elements)
        pw.Positioned(left:mm(node.element.x),top:mm(node.element.y),
          child:pw.Transform.rotate(angle:rotation(node),child:pw.SizedBox(
            width:mm(node.element.width),height:mm(node.element.height),child:element(node)))),
    ])),
  );

  pw.Widget _box(DesignRenderStyle s, Color fill, {pw.Widget? child}) => pw.Stack(children:[
    if(fill.a > 0) pw.Positioned.fill(child:pw.Opacity(opacity:fill.a,
      child:pw.DecoratedBox(decoration:pw.BoxDecoration(color:color(fill),borderRadius:pw.BorderRadius.circular(mm(s.radius)))))),
    if(s.borderWidth > 0 && s.border.a > 0) pw.Positioned.fill(child:pw.Opacity(opacity:s.border.a,
      child:pw.DecoratedBox(decoration:pw.BoxDecoration(border:pw.Border.all(color:color(s.border),width:mm(s.borderWidth)),
        borderRadius:pw.BorderRadius.circular(mm(s.radius)))))),
    if(child != null) pw.Positioned.fill(child:pw.Padding(padding:pw.EdgeInsets.all(mm(s.borderWidth)),child:child)),
  ]);

  pw.Widget element(DesignRenderElement node) {
    final s = node.style;
    switch (node.element.type) {
      case DesignElementType.rectangle:
        return _box(s,s.fill);
      case DesignElementType.line:
        return pw.Center(child:pw.Opacity(opacity:s.color.a,
          child:pw.Container(height:mm(s.borderWidth),color:color(s.color))));
      case DesignElementType.studentPhoto:
      case DesignElementType.schoolLogo:
        final image=images[node.imageUrl];
        return pw.ClipRRect(horizontalRadius:mm(s.radius),verticalRadius:mm(s.radius),
          child:_box(s,DesignRenderStyle.imageBackground,
            child:image == null ? pw.Center(child:pw.Text(
              node.element.type == DesignElementType.studentPhoto ? 'PHOTO' : 'LOGO',
              style:pw.TextStyle(font:fonts[400],fontSize:mm(2),color:PdfColors.grey))) :
              pw.Image(image,fit:s.fit == BoxFit.contain ? pw.BoxFit.contain : pw.BoxFit.cover)));
      case DesignElementType.text:
      case DesignElementType.boundText:
      case DesignElementType.customFieldText:
        DesignFonts.validatePdfText(node.text);
        final lines = layoutDesignText(node);
        return pw.ClipRect(
          child: pw.Builder(
            builder: (context) {
              final font = fonts[s.weight]!.getFont(context);
              return pw.CustomPaint(
                painter: (canvas, size) {
                  canvas.setGraphicState(PdfGraphicState(opacity:s.color.a));
            canvas.setFillColor(color(s.color));
                  for (final line in lines) {
                    canvas.drawString(
                      font,
                      mm(s.fontSize),
                      line.text,
                      mm(line.x),
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
