import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design_render_scene.dart';

/// The PDF adapter uses Flutter's line breaks and baselines, not a second word
/// wrapping algorithm. All measurements stay in document millimetres.
class DesignTextLine {
  const DesignTextLine(this.text, this.x, this.baseline);
  final String text;
  final double x, baseline;
}

List<DesignTextLine> layoutDesignText(DesignRenderElement node) {
  final e = node.element;
  final painter = TextPainter(
    text: TextSpan(text: node.text, style: node.style.textStyle(1)),
    textAlign: node.style.alignment,
    textDirection: TextDirection.ltr,
    maxLines: node.style.maxLines,
    textScaler: TextScaler.noScaling,
  )..layout(maxWidth: e.width);
  try {
    final dx = switch (node.style.alignment) {
      TextAlign.center => (e.width - painter.width) / 2,
      TextAlign.right => e.width - painter.width,
      _ => 0.0,
    };
    final dy = (e.height - math.min(e.height, painter.height)) / 2;
    final lines = <DesignTextLine>[];
    var offset = 0;
    TextRange? previousRange;
    for (final metric in painter.computeLineMetrics()) {
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
