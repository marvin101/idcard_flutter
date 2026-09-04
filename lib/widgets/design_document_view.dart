import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../models/card_template.dart';
import '../models/design_bindings.dart';
import '../models/school_profile.dart';
import '../models/design_render_scene.dart';

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
<<<<<<< Updated upstream
    final elements = [...document.elements]
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: interactive ? () => onSelect?.call(null) : null,
=======
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
>>>>>>> Stashed changes
      child: ClipRect(
        child: ColoredBox(
          key: const Key('design-document-surface'),
          color: scene.background,
          child: Stack(
            children: [
<<<<<<< Updated upstream
              if (resolveDesignAssetUrl(
                    document.canvas.backgroundImage,
                    assetBaseUrl,
                  )
                  case final String url when url.isNotEmpty)
=======
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
>>>>>>> Stashed changes
                Positioned.fill(
                  child: IgnorePointer(
                    child: Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              for (final node in scene.elements)
                for (final element in [node.element])
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
    final s = node.style;
    switch (node.element.type) {
      case DesignElementType.rectangle:
        return DecoratedBox(
          decoration: BoxDecoration(
            color: s.fill,
            border: Border.all(color: s.border, width: s.borderWidth * scale),
            borderRadius: BorderRadius.circular(s.radius * scale),
          ),
        );
      case DesignElementType.line:
        return Center(
          child: Container(height: s.borderWidth * scale, color: s.color),
        );
      case DesignElementType.studentPhoto:
      case DesignElementType.schoolLogo:
        final fallback = node.element.type == DesignElementType.studentPhoto
            ? Icons.person_outline
            : Icons.school_outlined;
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: DesignRenderStyle.imageBackground,
            border: Border.all(color: s.border, width: s.borderWidth * scale),
            borderRadius: BorderRadius.circular(s.radius * scale),
          ),
          child: node.imageUrl == null
              ? Icon(fallback, color: Colors.grey, size: 6 * scale)
              : Image.network(
                  node.imageUrl!,
                  fit: s.fit,
                  errorBuilder: (_, _, _) =>
                      Icon(fallback, color: Colors.grey, size: 6 * scale),
                ),
        );
      case DesignElementType.text:
      case DesignElementType.boundText:
      case DesignElementType.customFieldText:
        return Align(
          alignment: switch (s.alignment) {
            TextAlign.center => Alignment.center,
            TextAlign.right => Alignment.centerRight,
            _ => Alignment.centerLeft,
          },
          child: Text(
            node.text,
            textScaler: TextScaler.noScaling,
            textDirection: TextDirection.ltr,
            maxLines: s.maxLines,
            overflow: TextOverflow.clip,
            textAlign: s.alignment,
            style: s.textStyle(scale),
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
  final bool selected, interactive;
  final double scaleX, scaleY;
  final Widget child;
  final ValueChanged<String?>? onSelect;
  final void Function(String, double, double)? onMove, onResize;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: Key('design-element-${element.id}'),
    behavior: HitTestBehavior.opaque,
    onTap: interactive ? () => onSelect?.call(element.id) : null,
    onPanStart: interactive && !element.locked
        ? (_) => onSelect?.call(element.id)
        : null,
    onPanUpdate: interactive && !element.locked
        ? (details) => onMove?.call(
            element.id,
            details.delta.dx / scaleX,
            details.delta.dy / scaleY,
          )
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
              onPanUpdate: (details) => onResize?.call(
                element.id,
                details.delta.dx / scaleX,
                details.delta.dy / scaleY,
              ),
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
