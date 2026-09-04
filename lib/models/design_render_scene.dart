import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'card_template.dart';
import 'design_bindings.dart';

/// Shared interpretation only. Editor state and selection never enter this scene.
class DesignRenderScene {
  DesignRenderScene({
    required DesignDocument document,
    required DesignBindings bindings,
    String? photoUrl,
    String? logoUrl,
    String? assetBaseUrl,
  }) : canvas = document.canvas,
       background = colorFromHex(document.canvas.backgroundColor, Colors.white),
       backgroundImage = resolveDesignAssetUrl(
         document.canvas.backgroundImage,
         assetBaseUrl,
       ),
       elements = List.unmodifiable(
         (document.elements.where((e) => e.visible).toList()
               ..sort((a, b) => a.zIndex.compareTo(b.zIndex)))
             .map(
               (e) => DesignRenderElement(
                 e,
                 bindings.text(e),
                 resolveDesignAssetUrl(switch (e.type) {
                   DesignElementType.studentPhoto =>
                     photoUrl ?? bindings.student.photoPath,
                   DesignElementType.schoolLogo =>
                     logoUrl ??
                         bindings.schoolProfile?.logoUrl ??
                         bindings.schoolProfile?.logoPath,
                   _ => null,
                 }, assetBaseUrl),
               ),
             ),
       );
  final DesignCanvas canvas;
  final Color background;
  final String? backgroundImage;
  final List<DesignRenderElement> elements;
}

class DesignRenderElement {
  DesignRenderElement(this.element, this.text, this.imageUrl)
    : style = DesignRenderStyle(element);
  final DesignElement element;
  final String text;
  final String? imageUrl;
  final DesignRenderStyle style;
  double get radians => element.rotation * math.pi / 180;
}

class DesignRenderStyle {
  DesignRenderStyle(DesignElement e)
    : color = colorFromHex(e.style['color'], Colors.black),
      fill = colorFromHex(e.style['fill_color'], Colors.transparent),
      border = colorFromHex(e.style['border_color'], Colors.transparent),
      borderWidth = _number(
        e.style['border_width'],
        e.type == DesignElementType.line ? .5 : 0,
        0,
      ),
      radius = _number(e.style['corner_radius'], 0, 0),
      fontSize = _number(e.style['font_size'], 3, .1),
      weight =
          (((e.style['font_weight'] as num?)?.toInt() ?? 400).clamp(100, 900) ~/
              100) *
          100,
      maxLines = math.max(1, (e.style['max_lines'] as num?)?.toInt() ?? 2),
      alignment = switch (e.style['alignment']) {
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        _ => TextAlign.left,
      },
      fit = e.style['fit'] == 'contain' ? BoxFit.contain : BoxFit.cover;
  static const fontFamily = 'CardNotoSans';
  static const imageBackground = Color(0xffeef1f5);
  final Color color, fill, border;
  final double borderWidth, radius, fontSize;
  final int weight, maxLines;
  final TextAlign alignment;
  final BoxFit fit;
  TextStyle textStyle(double scale) => TextStyle(
    inherit: false,
    fontFamily: fontFamily,
    fontSize: fontSize * scale,
    fontWeight: FontWeight.values[weight ~/ 100 - 1],
    color: color,
    height: 1,
    letterSpacing: 0,
    wordSpacing: 0,
  );
  static double _number(Object? value, double fallback, double minimum) =>
      value is num && value.isFinite
      ? math.max(minimum, value.toDouble())
      : fallback;
}
