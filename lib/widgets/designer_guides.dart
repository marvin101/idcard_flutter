import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/card_template.dart';

@immutable
class DesignerGuide {
  const DesignerGuide(
    this.axis,
    this.position,
    this.start,
    this.end,
    this.targetId,
    this.anchor,
  );
  final Axis axis;
  final double position, start, end;
  final String targetId;
  final int anchor;
}

/// Editor-only references. Grid snapping controls placement; guides never alter
/// geometry, so the two systems cannot pull a drag in different directions.
abstract final class DesignerGuides {
  static const tolerancePixels = 5.0;

  static Rect bounds(DesignElement e) {
    final angle = e.rotation * math.pi / 180;
    final width =
        e.width * math.cos(angle).abs() + e.height * math.sin(angle).abs();
    final height =
        e.height * math.cos(angle).abs() + e.width * math.sin(angle).abs();
    return Rect.fromCenter(
      center: Offset(e.x + e.width / 2, e.y + e.height / 2),
      width: width,
      height: height,
    );
  }

  static List<DesignerGuide> detect({
    required DesignElement moving,
    required Iterable<DesignElement> elements,
    required double pixelsPerMm,
  }) {
    if (!pixelsPerMm.isFinite || pixelsPerMm <= 0) return const [];
    final tolerance = tolerancePixels / pixelsPerMm;
    final box = bounds(moving);
    final others =
        elements.where((e) => e.id != moving.id && e.visible).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final guides = <DesignerGuide>[];
    for (final axis in Axis.values) {
      final source = axis == Axis.vertical
          ? [box.left, box.center.dx, box.right]
          : [box.top, box.center.dy, box.bottom];
      double distance = tolerance + 1e-9;
      DesignerGuide? closest;
      for (final other in others) {
        final target = bounds(other);
        final anchors = axis == Axis.vertical
            ? [target.left, target.center.dx, target.right]
            : [target.top, target.center.dy, target.bottom];
        for (var i = 0; i < 3; i++) {
          for (final position in anchors) {
            final delta = (source[i] - position).abs();
            if (delta >= distance) continue;
            distance = delta;
            closest = DesignerGuide(
              axis,
              position,
              (axis == Axis.vertical
                      ? math.min(box.top, target.top)
                      : math.min(box.left, target.left)) -
                  tolerance,
              (axis == Axis.vertical
                      ? math.max(box.bottom, target.bottom)
                      : math.max(box.right, target.right)) +
                  tolerance,
              other.id,
              i,
            );
          }
        }
      }
      if (closest != null) guides.add(closest);
    }
    return guides;
  }
}

class DesignerGuideOverlay extends StatelessWidget {
  const DesignerGuideOverlay({
    super.key,
    required this.guides,
    required this.canvasWidth,
    required this.viewScale,
  });
  final List<DesignerGuide> guides;
  final double canvasWidth, viewScale;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(painter: _GuidePainter(guides, canvasWidth, viewScale)),
  );
}

class _GuidePainter extends CustomPainter {
  const _GuidePainter(this.guides, this.canvasWidth, this.viewScale);
  final List<DesignerGuide> guides;
  final double canvasWidth, viewScale;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / canvasWidth;
    final paint = Paint()
      ..color = const Color(0xffe11d8d)
      ..strokeWidth = 1 / viewScale;
    for (final guide in guides) {
      final a = guide.axis == Axis.vertical
          ? Offset(guide.position, guide.start)
          : Offset(guide.start, guide.position);
      final b = guide.axis == Axis.vertical
          ? Offset(guide.position, guide.end)
          : Offset(guide.end, guide.position);
      canvas.drawLine(a * scale, b * scale, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter old) =>
      old.guides != guides ||
      old.canvasWidth != canvasWidth ||
      old.viewScale != viewScale;
}
