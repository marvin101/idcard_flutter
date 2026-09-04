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
    return [
      for (final metric in painter.computeLineMetrics())
        DesignTextLine(
          _lineText(painter, node.text, metric),
          dx + metric.left,
          dy + metric.baseline,
        ),
    ];
  } finally {
    painter.dispose();
  }
}

String _lineText(TextPainter painter, String text, LineMetrics metric) {
  final position = painter.getPositionForOffset(
    Offset(metric.left, metric.baseline - metric.ascent / 2),
  );
  final range = painter.getLineBoundary(position);
  return text
      .substring(range.start, range.end)
      .replaceAll(RegExp(r'[\r\n]+$'), '');
}
