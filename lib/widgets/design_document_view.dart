import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../models/card_template.dart';
import '../models/design_bindings.dart';
import '../models/design_render_scene.dart';
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
  });

  final String? schoolName;
  final String? assetBaseUrl;
  final SchoolProfile? schoolProfile;

  final DesignDocument document;
  final ApiStudent student;

  final String? sessionName;
  final String? className;
  final String? sectionName;
  final String? photoUrl;
  final String? logoUrl;
  final String? selectedId;

  final bool interactive;

  final ValueChanged<String?>? onSelect;
  final void Function(String id, double dx, double dy)? onMove;
  final void Function(String id, double dw, double dh)? onResize;

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

              if (scene.backgroundImage case final String url
                  when url.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),

              for (final node in scene.elements)
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
                    onSelect: onSelect,
                    onMove: onMove,
                    onResize: onResize,
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
            border: Border.all(
              color: style.border,
              width: style.borderWidth * scale,
            ),
            borderRadius: BorderRadius.circular(style.radius * scale),
          ),
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
        final fallbackIcon = node.element.type == DesignElementType.studentPhoto
            ? Icons.person_outline
            : Icons.school_outlined;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: DesignRenderStyle.imageBackground,
            border: Border.all(
              color: style.border,
              width: style.borderWidth * scale,
            ),
            borderRadius: BorderRadius.circular(style.radius * scale),
          ),
          child: node.imageUrl == null
              ? Icon(fallbackIcon, color: Colors.grey, size: 6 * scale)
              : Image.network(
                  node.imageUrl!,
                  fit: style.fit,
                  errorBuilder: (_, __, ___) {
                    return Icon(
                      fallbackIcon,
                      color: Colors.grey,
                      size: 6 * scale,
                    );
                  },
                ),
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

class _InteractiveElement extends StatelessWidget {
  const _InteractiveElement({
    required this.element,
    required this.selected,
    required this.interactive,
    required this.scaleX,
    required this.scaleY,
    required this.child,
    this.onSelect,
    this.onMove,
    this.onResize,
  });

  final DesignElement element;

  final bool selected;
  final bool interactive;

  final double scaleX;
  final double scaleY;

  final Widget child;

  final ValueChanged<String?>? onSelect;
  final void Function(String id, double dx, double dy)? onMove;
  final void Function(String id, double dw, double dh)? onResize;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('design-element-${element.id}'),
      behavior: HitTestBehavior.opaque,

      // onTapDown gives immediate selection feedback instead of waiting
      // for the complete tap gesture to resolve.
      onTapDown: interactive ? (_) => onSelect?.call(element.id) : null,

      onPanStart: interactive && !element.locked
          ? (_) => onSelect?.call(element.id)
          : null,

      onPanUpdate: interactive && !element.locked
          ? (details) {
              onMove?.call(
                element.id,
                details.delta.dx / scaleX,
                details.delta.dy / scaleY,
              );
            }
          : null,

      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: selected
                    ? Border.all(color: Colors.blue, width: 1.5)
                    : null,
              ),
              child: child,
            ),
          ),

          if (selected && interactive && !element.locked)
            Positioned(
              right: -6,
              bottom: -6,
              child: GestureDetector(
                key: Key('resize-${element.id}'),
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  onResize?.call(
                    element.id,
                    details.delta.dx / scaleX,
                    details.delta.dy / scaleY,
                  );
                },
                child: Container(
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
        ],
      ),
    );
  }
}
