import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../models/api_personnel.dart';
import '../models/card_template.dart';
import '../models/design_bindings.dart';
import '../models/design_render_scene.dart';
import '../models/school_profile.dart';
import 'design_qr_code.dart';
import 'design_barcode.dart';

class DesignDocumentView extends StatelessWidget {
  const DesignDocumentView({
    super.key,
    required this.document,
    this.student,
    this.personnel,
    this.sessionName,
    this.className,
    this.sectionName,
    this.photoUrl,
    this.logoUrl,
    this.schoolName,
    this.schoolProfile,
    this.assetBaseUrl,
    this.selectedId,
    this.interactive = false,
    this.onSelect,
    this.onMove,
    this.onResize,
    this.onResizeHandle,
    this.onGestureStart,
    this.onGestureEnd,
    this.isGestureActive,
  }) : assert(student != null || personnel != null);

  final String? schoolName;
  final String? assetBaseUrl;
  final SchoolProfile? schoolProfile;

  final DesignDocument document;
  final ApiStudent? student;
  final ApiPersonnel? personnel;
  final String? sessionName;
  final String? className;
  final String? sectionName;
  final String? photoUrl;
  final String? logoUrl;
  final String? selectedId;

  final ValueChanged<String>? onGestureStart;
  final VoidCallback? onGestureEnd;
  final bool Function(String)? isGestureActive;
  final bool interactive;

  final ValueChanged<String?>? onSelect;
  final void Function(String id, double dx, double dy)? onMove;
  final void Function(String id, double dw, double dh)? onResize;
  final void Function(String id, String handle, double dx, double dy)?
  onResizeHandle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use one uniform scale so the document keeps its real aspect ratio.
        // Do not derive orientation from the parent container.
        final widthScale = constraints.maxWidth / document.canvas.width;
        final heightScale = constraints.maxHeight / document.canvas.height;

        final available = math.min(widthScale, heightScale);

        // 3.78 px/mm is roughly 96 DPI and provides a sane fallback when
        // LayoutBuilder receives unconstrained dimensions.
        final scale = available.isFinite && available > 0 ? available : 3.78;

        return Align(
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(
            width: document.canvas.width * scale,
            height: document.canvas.height * scale,
            child: _canvas(context, scale),
          ),
        );
      },
    );
  }

  Widget _canvas(BuildContext context, double scale) {
    final scene = DesignRenderScene(
      document: document,
      bindings: DesignBindings(
        student: student,
        personnel: personnel,
        sessionName: sessionName,
        className: className,
        sectionName: sectionName,
        schoolName: schoolName,
        schoolProfile: schoolProfile,
      ),
      photoUrl: photoUrl,
      logoUrl: logoUrl,
      assetBaseUrl: assetBaseUrl,
    );

    final elements = [...scene.elements]
      ..sort((a, b) => a.element.zIndex.compareTo(b.element.zIndex));
    return RepaintBoundary(
      child: ClipRect(
        child: ColoredBox(
          key: const Key('design-document-surface'),
          color: scene.background,
          child: Stack(
            children: [
              // This sits behind all elements, so it only handles pointer
              // events that land on empty canvas space.
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: interactive
                      ? (_) => onSelect?.call(null)
                      : null,
                ),
              ),
              if (resolveDesignAssetUrl(
                    document.canvas.backgroundImage,
                    assetBaseUrl,
                  )
                  case final String url when url.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
              for (final node in elements)
                if (node.element.visible)
                  Positioned(
                    key: ValueKey(node.element.id),
                    left: node.element.x * scale,
                    top: node.element.y * scale,
                    width: node.element.width * scale,
                    height: node.element.height * scale,
                    child: _InteractiveElement(
                      element: node.element,
                      selected: selectedId == node.element.id,
                      interactive: interactive,
                      scaleX: scale,
                      scaleY: scale,
                      canvasContext: context,
                      onGestureStart: onGestureStart,
                      onGestureEnd: onGestureEnd,
                      isGestureActive: isGestureActive,
                      onSelect: onSelect,
                      onMove: onMove,
                      onResize: onResize,
                      onResizeHandle: onResizeHandle,
                      child: Transform.rotate(
                        angle: node.radians,
                        child: _render(node, scale),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _render(DesignRenderElement node, double scale) {
    final style = node.style;

    switch (node.element.type) {
      case DesignElementType.rectangle:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: style.fill,
            border: style.borderWidth > 0
                ? Border.all(
                    color: style.border,
                    width: style.borderWidth * scale,
                  )
                : null,
            borderRadius: BorderRadius.circular(style.radius * scale),
          ),
        );

      case DesignElementType.roundedRectangle:
      case DesignElementType.ellipse:
      case DesignElementType.circle:
      case DesignElementType.triangle:
      case DesignElementType.bloodDrop:
        return CustomPaint(
          painter: _DesignerShapePainter(node.element.type, style, scale),
          child: node.element.type == DesignElementType.bloodDrop
              ? Align(
                  alignment: const Alignment(0, .35),
                  child: Text(
                    node.text,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 3.2 * scale,
                    ),
                  ),
                )
              : null,
        );

      case DesignElementType.line:
        return Center(
          child: Container(
            height: style.borderWidth * scale,
            color: style.color,
          ),
        );

      case DesignElementType.studentPhoto:
      case DesignElementType.schoolLogo:
      case DesignElementType.principalSignature:
        final fallbackIcon = switch (node.element.type) {
          DesignElementType.studentPhoto => Icons.person_outline,
          DesignElementType.principalSignature => Icons.draw_outlined,
          _ => Icons.school_outlined,
        };

        final fallback =
            node.element.type == DesignElementType.principalSignature
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(fallbackIcon, color: Colors.grey, size: 4 * scale),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Principal signature',
                      style: TextStyle(color: Colors.grey, fontSize: 2 * scale),
                    ),
                  ),
                ],
              )
            : Icon(fallbackIcon, color: Colors.grey, size: 6 * scale);

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: style.imageShape == 'oval'
              ? ShapeDecoration(
                  color: DesignRenderStyle.imageBackground,
                  shape: OvalBorder(
                    side: style.borderWidth > 0
                        ? BorderSide(
                            color: style.border,
                            width: style.borderWidth * scale,
                          )
                        : BorderSide.none,
                  ),
                )
              : BoxDecoration(
                  color: DesignRenderStyle.imageBackground,
                  border: style.borderWidth > 0
                      ? Border.all(
                          color: style.border,
                          width: style.borderWidth * scale,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(
                    (style.imageShape == 'rounded' ? style.radius : 0) * scale,
                  ),
                ),
          child: node.imageUrl == null
              ? fallback
              : Image.network(
                  node.imageUrl!,
                  fit: style.fit,
                  errorBuilder: (_, _, _) => fallback,
                ),
        );

      case DesignElementType.qrCode:
        return DesignQrCode(
          data: node.text,
          color: style.color,
          backgroundColor: style.qrBackground,
          quietZone: style.quietZone * scale,
          errorCorrection: style.errorCorrection,
        );

      case DesignElementType.barcode:
        return DesignBarcode(
          data: node.text,
          symbology: node.element.data['symbology'] as String? ?? 'code128',
          color: style.color,
          backgroundColor: style.qrBackground,
          quietZone: style.quietZone * scale,
          showText: style.showText,
          fontSize: style.fontSize * scale,
        );

      case DesignElementType.text:
      case DesignElementType.boundText:
      case DesignElementType.customFieldText:
        return Align(
          alignment: switch (style.alignment) {
            TextAlign.center => Alignment.center,
            TextAlign.right => Alignment.centerRight,
            _ => Alignment.centerLeft,
          },
          child: Text(
            node.text,
            textScaler: TextScaler.noScaling,
            textDirection: TextDirection.ltr,
            maxLines: style.maxLines,
            overflow: TextOverflow.clip,
            textAlign: style.alignment,
            style: style.textStyle(scale),
          ),
        );
    }
  }
}

class _DesignerShapePainter extends CustomPainter {
  const _DesignerShapePainter(this.type, this.style, this.scale);
  final DesignElementType type;
  final DesignRenderStyle style;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = style.borderWidth * scale;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      math.max(0, size.width - stroke),
      math.max(0, size.height - stroke),
    );
    final path = Path();
    switch (type) {
      case DesignElementType.ellipse:
      case DesignElementType.circle:
        path.addOval(rect);
      case DesignElementType.triangle:
        path.moveTo(rect.center.dx, rect.top);
        path.lineTo(rect.right, rect.bottom);
        path.lineTo(rect.left, rect.bottom);
        path.close();
      case DesignElementType.bloodDrop:
        path.moveTo(rect.center.dx, rect.top);
        path.cubicTo(
          rect.width * .14,
          rect.height * .34,
          rect.left,
          rect.height * .53,
          rect.left,
          rect.height * .69,
        );
        path.cubicTo(
          rect.left,
          rect.bottom,
          rect.right,
          rect.bottom,
          rect.right,
          rect.height * .69,
        );
        path.cubicTo(
          rect.right,
          rect.height * .53,
          rect.width * .86,
          rect.height * .34,
          rect.center.dx,
          rect.top,
        );
        path.close();
      default:
        path.addRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(style.radius * scale)),
        );
    }
    if (style.fill.a > 0) {
      canvas.drawPath(path, Paint()..color = style.fill);
    }
    if (stroke > 0 && style.border.a > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = style.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DesignerShapePainter oldDelegate) =>
      type != oldDelegate.type ||
      style != oldDelegate.style ||
      scale != oldDelegate.scale;
}

// Only pointer bookkeeping is local. Every content/geometry value is supplied
// by the live document; raw input avoids gesture-arena delay on mouse selection.
class _InteractiveElement extends StatefulWidget {
  const _InteractiveElement({
    required this.element,
    required this.selected,
    required this.interactive,
    required this.scaleX,
    required this.scaleY,
    required this.canvasContext,
    required this.child,
    this.onSelect,
    this.onMove,
    this.onResize,
    this.onResizeHandle,
    this.onGestureStart,
    this.onGestureEnd,
    this.isGestureActive,
  });

  final DesignElement element;
  final bool selected;
  final bool interactive;

  final double scaleX;
  final double scaleY;
  final BuildContext canvasContext;
  final Widget child;

  final ValueChanged<String?>? onSelect;
  final ValueChanged<String>? onGestureStart;
  final VoidCallback? onGestureEnd;
  final bool Function(String)? isGestureActive;
  final void Function(String, double, double)? onMove;
  final void Function(String, double, double)? onResize;
  final void Function(String, String, double, double)? onResizeHandle;
  @override
  State<_InteractiveElement> createState() => _InteractiveElementState();
}

class _InteractiveElementState extends State<_InteractiveElement> {
  int? _pointer;
  String? _resizeHandle;
  void _down(PointerDownEvent event) {
    if (!widget.interactive || event.buttons != 1 || _pointer != null) {
      return;
    }
    final size = context.size!;
    _resizeHandle = null;
    if (widget.selected && !widget.element.locked) {
      const hit = 12.0;
      final x = event.localPosition.dx;
      final y = event.localPosition.dy;
      final left = x <= hit;
      final right = x >= size.width - hit;
      final top = y <= hit;
      final bottom = y >= size.height - hit;
      final image = {
        DesignElementType.studentPhoto,
        DesignElementType.schoolLogo,
        DesignElementType.principalSignature,
        DesignElementType.qrCode,
        DesignElementType.circle,
      }.contains(widget.element.type);
      if (widget.element.type == DesignElementType.line) {
        if (left) {
          _resizeHandle = 'left';
        } else if (right) {
          _resizeHandle = 'right';
        }
      } else if (left && top) {
        _resizeHandle = 'top-left';
      } else if (right && top) {
        _resizeHandle = 'top-right';
      } else if (left && bottom) {
        _resizeHandle = 'bottom-left';
      } else if (right && bottom) {
        _resizeHandle = 'bottom-right';
      } else if (!image && left) {
        _resizeHandle = 'left';
      } else if (!image && right) {
        _resizeHandle = 'right';
      } else if (!image && top) {
        _resizeHandle = 'top';
      } else if (!image && bottom) {
        _resizeHandle = 'bottom';
      }
    }
    widget.onSelect?.call(widget.element.id);
    if (widget.element.locked) return;
    _pointer = event.pointer;
    widget.onGestureStart?.call(widget.element.id);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer ||
        widget.isGestureActive?.call(widget.element.id) == false) {
      return;
    }
    final box = widget.canvasContext.findRenderObject()! as RenderBox;
    // Convert both endpoints through the same canvas transform. This includes
    // InteractiveViewer zoom and avoids the moving element's local origin.
    final delta =
        box.globalToLocal(event.position) -
        box.globalToLocal(event.position - event.delta);
    if (_resizeHandle case final String handle) {
      if (widget.onResizeHandle != null) {
        widget.onResizeHandle!(
          widget.element.id,
          handle,
          delta.dx / widget.scaleX,
          delta.dy / widget.scaleY,
        );
      } else {
        widget.onResize?.call(
          widget.element.id,
          delta.dx / widget.scaleX,
          delta.dy / widget.scaleY,
        );
      }
    } else {
      widget.onMove?.call(
        widget.element.id,
        delta.dx / widget.scaleX,
        delta.dy / widget.scaleY,
      );
    }
  }

  void _end(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    widget.onGestureEnd?.call();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.element.locked
        ? SystemMouseCursors.basic
        : SystemMouseCursors.move,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: widget.interactive && !widget.element.locked ? (_) {} : null,
      child: Listener(
        key: Key('design-element-${widget.element.id}'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _end,
        onPointerCancel: _end,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: widget.selected
                      ? Border.all(color: Colors.blue, width: 1.5)
                      : null,
                ),
                child: RepaintBoundary(child: widget.child),
              ),
            ),
            if (widget.selected && widget.interactive && !widget.element.locked)
              for (final handle in [
                if (widget.element.type == DesignElementType.line) ...[
                  'left',
                  'right',
                ] else ...[
                  'top-left',
                  'top-right',
                  'bottom-left',
                  'bottom-right',
                  if (!{
                    DesignElementType.studentPhoto,
                    DesignElementType.schoolLogo,
                    DesignElementType.principalSignature,
                    DesignElementType.qrCode,
                    DesignElementType.circle,
                  }.contains(widget.element.type)) ...[
                    'top',
                    'right',
                    'bottom',
                    'left',
                  ],
                ],
              ])
                Positioned.fill(
                  child: IgnorePointer(
                    child: Align(
                      alignment: switch (handle) {
                        'top-left' => Alignment.topLeft,
                        'top-right' => Alignment.topRight,
                        'bottom-left' => Alignment.bottomLeft,
                        'top' => Alignment.topCenter,
                        'right' => Alignment.centerRight,
                        'bottom' => Alignment.bottomCenter,
                        'left' => Alignment.centerLeft,
                        _ => Alignment.bottomRight,
                      },
                      child: Container(
                        key: Key(
                          handle == 'bottom-right'
                              ? 'resize-${widget.element.id}'
                              : 'resize-${widget.element.id}-$handle',
                        ),
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border.fromBorderSide(
                            BorderSide(color: Colors.blue, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}
