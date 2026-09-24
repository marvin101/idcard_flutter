import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'design_render_scene.dart';

/// The PDF adapter uses Flutter's line breaks and baselines, not a second word
/// wrapping algorithm. All measurements stay in document millimetres.
class DesignTextLine {
  const DesignTextLine(this.text, this.x, this.baseline);

  final String text;
  final double x;
  final double baseline;
}

/// Creates the TextPainter used for both wrap detection and PDF text layout.
///
/// Keeping this in one place ensures that wrap detection uses exactly the same
/// font, width, maximum-line, alignment, and scaling rules as PDF rendering.
TextPainter _designTextPainter(DesignRenderElement node) {
  final e = node.element;

  return TextPainter(
    text: TextSpan(text: node.text, style: node.style.textStyle(1)),
    textAlign: node.style.alignment,
    textDirection: TextDirection.ltr,
    maxLines: node.style.maxLines,
    textScaler: TextScaler.noScaling,
  )..layout(maxWidth: e.width);
}

/// Returns true when the resolved element text occupies more than one rendered
/// line inside the element's configured width.
///
/// This is intentionally based on the same TextPainter used by PDF layout so
/// Flutter preview/designer and PDF rendering can make the same decision about
/// vertical placement.
bool designTextIsMultiline(DesignRenderElement node) {
  final painter = _designTextPainter(node);

  try {
    return painter.computeLineMetrics().length > 1;
  } finally {
    painter.dispose();
  }
}

List<DesignTextLine> layoutDesignText(DesignRenderElement node) {
  final e = node.element;
  final painter = _designTextPainter(node);

  try {
    final metrics = painter.computeLineMetrics();

    final dx = switch (node.style.alignment) {
      TextAlign.center => (e.width - painter.width) / 2,
      TextAlign.right => e.width - painter.width,
      _ => 0.0,
    };

    // A single-line element keeps the existing centred behaviour.
    //
    // Once the text wraps, however, its first line must remain anchored to the
    // top of the element. Otherwise adding another line changes the vertical
    // centre of the entire text block and makes dynamic values such as long
    // addresses appear to jump inside their saved box.
    final dy = metrics.length > 1
        ? 0.0
        : (e.height - math.min(e.height, painter.height)) / 2;

    final lines = <DesignTextLine>[];

    var offset = 0;
    TextRange? previousRange;

    for (final metric in metrics) {
      var range = painter.getLineBoundary(
        TextPosition(offset: offset, affinity: TextAffinity.downstream),
      );

      while (previousRange != null &&
          range.start == previousRange.start &&
          range.end == previousRange.end &&
          offset < node.text.length) {
        range = painter.getLineBoundary(
          TextPosition(offset: ++offset, affinity: TextAffinity.downstream),
        );
      }

      lines.add(
        DesignTextLine(
          _lineText(node.text, range),
          dx + metric.left,
          dy + metric.baseline,
        ),
      );

      previousRange = range;
      offset = range.end.clamp(0, node.text.length);
    }

    return lines;
  } finally {
    painter.dispose();
  }
}

String _lineText(String text, TextRange range) {
  return text
      .substring(range.start, range.end)
      .replaceAll(RegExp(r'[\r\n]+$'), '');
}
