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

/// Returns the vertical offset at which text should begin inside its saved
/// element box.
///
/// The important rule is that the first rendered line keeps the same vertical
/// position whether the value occupies one line or several lines.
///
/// A designer may intentionally use a tall text element while placing a
/// single-line value around its vertical centre. If that value later wraps,
/// centring the entire multiline block moves the first line upward. Anchoring
/// the multiline block to the top moves it even farther upward.
///
/// Instead, we centre one line inside the configured element and use that
/// position as the permanent first-line anchor. Additional wrapped lines then
/// continue downward from there.
double designTextTopOffset(DesignRenderElement node) {
  final painter = _designTextPainter(node);

  try {
    final metrics = painter.computeLineMetrics();

    if (metrics.isEmpty) {
      return 0;
    }

    final firstLineHeight = metrics.first.height;

    return math.max(0.0, (node.element.height - firstLineHeight) / 2);
  } finally {
    painter.dispose();
  }
}

List<DesignTextLine> layoutDesignText(DesignRenderElement node) {
  final e = node.element;
  final painter = _designTextPainter(node);

  try {
    final metrics = painter.computeLineMetrics();

    if (metrics.isEmpty) {
      return const <DesignTextLine>[];
    }

    final dx = switch (node.style.alignment) {
      TextAlign.center => (e.width - painter.width) / 2,
      TextAlign.right => e.width - painter.width,
      _ => 0.0,
    };

    // Preserve the original single-line vertical position. If the value wraps,
    // subsequent lines grow downward instead of re-centring the whole block.
    final dy = math.max(0.0, (e.height - metrics.first.height) / 2);

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
