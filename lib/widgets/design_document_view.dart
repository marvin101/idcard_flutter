import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

import '../models/api_student.dart';
import '../models/card_template.dart';
import '../models/design_bindings.dart';
import '../models/school_profile.dart';

class DesignDocumentView extends StatelessWidget {
  const DesignDocumentView({
    super.key,
    required this.document,
    required this.student,
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
    this.onGestureStart,
    this.onGestureEnd,
    this.isGestureActive,
  });

  final String? schoolName, assetBaseUrl;
  final SchoolProfile? schoolProfile;
  final DesignDocument document;
  final ApiStudent student;
  final String? sessionName,
      className,
      sectionName,
      photoUrl,
      logoUrl,
      selectedId;
  final ValueChanged<String>? onGestureStart;
  final VoidCallback? onGestureEnd;
  final bool Function(String)? isGestureActive;
  final bool interactive;
  final ValueChanged<String?>? onSelect;
  final void Function(String id, double dx, double dy)? onMove;
  final void Function(String id, double dw, double dh)? onResize;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // A single scale preserves the document even inside a tight container
      // whose aspect ratio differs. No orientation presets are applied here.
      final widthScale = constraints.maxWidth / document.canvas.width;
      final heightScale = constraints.maxHeight / document.canvas.height;
      final available = math.min(widthScale, heightScale);
      final scale = available.isFinite ? available : 3.78;
      return Align(
        widthFactor: 1,
        heightFactor: 1,
        child: SizedBox(
          width: document.canvas.width * scale,
          height: document.canvas.height * scale,
          child: LayoutBuilder(
            builder: (context, _) => _canvas(context, scale),
          ),
        ),
      );
    },
  );

  Widget _canvas(BuildContext context, double scale) {
    final elements = [...document.elements]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return RepaintBoundary(
      child: ClipRect(
        child: ColoredBox(
          key: const Key('design-document-surface'),
          color: colorFromHex(document.canvas.backgroundColor, Colors.white),
          child: Stack(
            children: [
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
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              for (final element in elements)
                if (element.visible)
                  Positioned(
                    key: ValueKey(element.id),
                    left: element.x * scale,
                    top: element.y * scale,
                    width: element.width * scale,
                    height: element.height * scale,
                    child: _InteractiveElement(
                      element: element,
                      selected: selectedId == element.id,
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
                      child: Transform.rotate(
                        angle: element.rotation * math.pi / 180,
                        child: _render(element, scale),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _render(DesignElement element, double scale) {
    final style = element.style;
    final color = colorFromHex(style['color'], Colors.black);
    final alignment = switch (style['alignment']) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
    switch (element.type) {
      case DesignElementType.rectangle:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorFromHex(style['fill_color'], Colors.transparent),
            border: Border.all(
              color: colorFromHex(style['border_color'], Colors.transparent),
              width: ((style['border_width'] as num?)?.toDouble() ?? 0) * scale,
            ),
            borderRadius: BorderRadius.circular(
              ((style['corner_radius'] as num?)?.toDouble() ?? 0) * scale,
            ),
          ),
        );
      case DesignElementType.line:
        return Center(
          child: Container(
            height:
                math.max(0, (style['border_width'] as num?)?.toDouble() ?? .5) *
                scale,
            color: colorFromHex(style['color'], Colors.black),
          ),
        );
      case DesignElementType.studentPhoto:
        return _image(
          resolveDesignAssetUrl(photoUrl ?? student.photoPath, assetBaseUrl),
          style,
          Icons.person_outline,
          scale,
        );
      case DesignElementType.schoolLogo:
        return _image(
          resolveDesignAssetUrl(
            logoUrl ?? schoolProfile?.logoUrl ?? schoolProfile?.logoPath,
            assetBaseUrl,
          ),
          style,
          Icons.school_outlined,
          scale,
        );
      case DesignElementType.text:
      case DesignElementType.boundText:
      case DesignElementType.customFieldText:
        final text = DesignBindings(
          student: student,
          sessionName: sessionName,
          className: className,
          sectionName: sectionName,
          schoolName: schoolName,
          schoolProfile: schoolProfile,
        ).text(element);
        return Align(
          alignment: switch (alignment) {
            TextAlign.center => Alignment.center,
            TextAlign.right => Alignment.centerRight,
            _ => Alignment.centerLeft,
          },
          child: Text(
            text,
            textScaler: TextScaler.noScaling,
            maxLines: (style['max_lines'] as num?)?.toInt() ?? 2,
            overflow: TextOverflow.clip,
            textAlign: alignment,
            style: TextStyle(
              color: color,
              fontSize: ((style['font_size'] as num?)?.toDouble() ?? 3) * scale,
              fontWeight:
                  FontWeight.values[((style['font_weight'] as num?)?.toInt() ??
                                  400)
                              .clamp(100, 900) ~/
                          100 -
                      1],
              height: 1,
            ),
          ),
        );
    }
  }

  Widget _image(
    String? url,
    Map<String, dynamic> style,
    IconData fallback,
    double scale,
  ) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xffeef1f5),
      border: Border.all(
        color: colorFromHex(style['border_color'], Colors.transparent),
        width: ((style['border_width'] as num?)?.toDouble() ?? 0) * scale,
      ),
      borderRadius: BorderRadius.circular(
        ((style['corner_radius'] as num?)?.toDouble() ?? 0) * scale,
      ),
    ),
    child: url == null || url.isEmpty
        ? Icon(fallback, color: Colors.grey, size: 6 * scale)
        : Image.network(
            url,
            fit: style['fit'] == 'contain' ? BoxFit.contain : BoxFit.cover,
            errorBuilder: (_, _, _) =>
                Icon(fallback, color: Colors.grey, size: 6 * scale),
          ),
  );
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
    this.onGestureStart,
    this.onGestureEnd,
    this.isGestureActive,
  });
  final DesignElement element;
  final bool selected, interactive;
  final double scaleX, scaleY;
  final BuildContext canvasContext;
  final Widget child;
  final ValueChanged<String?>? onSelect;
  final ValueChanged<String>? onGestureStart;
  final VoidCallback? onGestureEnd;
  final bool Function(String)? isGestureActive;
  final void Function(String, double, double)? onMove, onResize;
  @override
  State<_InteractiveElement> createState() => _InteractiveElementState();
}

class _InteractiveElementState extends State<_InteractiveElement> {
  int? _pointer;
  bool _resizing = false;
  void _down(PointerDownEvent event) {
    if (!widget.interactive ||
        event.buttons != kPrimaryButton ||
        _pointer != null) {
      return;
    }
    final size = context.size!;
    _resizing =
        widget.selected &&
        !widget.element.locked &&
        event.localPosition.dx >= size.width - 6 &&
        event.localPosition.dy >= size.height - 6;
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
    final callback = _resizing ? widget.onResize : widget.onMove;
    callback?.call(
      widget.element.id,
      delta.dx / widget.scaleX,
      delta.dy / widget.scaleY,
    );
  }

  void _end(PointerEvent event) {
    if (event.pointer != _pointer) return;
    _pointer = null;
    widget.onGestureEnd?.call();
  }

  @override
  Widget build(BuildContext context) => Listener(
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
          Positioned(
            right: -6,
            bottom: -6,
            child: Container(
              key: Key('resize-${widget.element.id}'),
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
      ],
    ),
  );
}
