import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/api_student.dart';
import '../models/card_template.dart';

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
    this.selectedId,
    this.interactive = false,
    this.onSelect,
    this.onMove,
    this.onResize,
  });

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
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: document.canvas.width / document.canvas.height,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final sx = constraints.maxWidth / document.canvas.width;
        final sy = constraints.maxHeight / document.canvas.height;
        final elements = [...document.elements]
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: interactive ? () => onSelect?.call(null) : null,
          child: ClipRect(
            child: ColoredBox(
              color: colorFromHex(
                document.canvas.backgroundColor,
                Colors.white,
              ),
              child: Stack(
                children: [
                  if (document.canvas.backgroundImage case final String url
                      when url.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  for (final element in elements)
                    if (element.visible)
                      Positioned(
                        left: element.x * sx,
                        top: element.y * sy,
                        width: element.width * sx,
                        height: element.height * sy,
                        child: _InteractiveElement(
                          element: element,
                          selected: selectedId == element.id,
                          interactive: interactive,
                          scaleX: sx,
                          scaleY: sy,
                          onSelect: onSelect,
                          onMove: onMove,
                          onResize: onResize,
                          child: Transform.rotate(
                            angle: element.rotation * math.pi / 180,
                            child: _render(element),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _render(DesignElement element) {
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
              width: ((style['border_width'] as num?)?.toDouble() ?? 0),
            ),
            borderRadius: BorderRadius.circular(
              (style['corner_radius'] as num?)?.toDouble() ?? 0,
            ),
          ),
        );
      case DesignElementType.line:
        return Center(
          child: Container(
            height: math.max(
              1,
              (style['border_width'] as num?)?.toDouble() ?? 1,
            ),
            color: colorFromHex(style['color'], Colors.black),
          ),
        );
      case DesignElementType.studentPhoto:
        return _image(photoUrl, style, Icons.person_outline);
      case DesignElementType.schoolLogo:
        return _image(logoUrl, style, Icons.school_outlined);
      case DesignElementType.text:
      case DesignElementType.boundText:
      case DesignElementType.customFieldText:
        final text = _text(element);
        return Align(
          alignment: switch (alignment) {
            TextAlign.center => Alignment.center,
            TextAlign.right => Alignment.centerRight,
            _ => Alignment.centerLeft,
          },
          child: Text(
            text,
            maxLines: (style['max_lines'] as num?)?.toInt() ?? 2,
            overflow: TextOverflow.clip,
            textAlign: alignment,
            style: TextStyle(
              color: color,
              fontSize: ((style['font_size'] as num?)?.toDouble() ?? 3) * 3.78,
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

  Widget _image(String? url, Map<String, dynamic> style, IconData fallback) =>
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xffeef1f5),
          border: Border.all(
            color: colorFromHex(style['border_color'], Colors.transparent),
            width: (style['border_width'] as num?)?.toDouble() ?? 0,
          ),
          borderRadius: BorderRadius.circular(
            (style['corner_radius'] as num?)?.toDouble() ?? 0,
          ),
        ),
        child: url == null || url.isEmpty
            ? Icon(fallback, color: Colors.grey)
            : Image.network(
                url,
                fit: style['fit'] == 'contain' ? BoxFit.contain : BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(fallback, color: Colors.grey),
              ),
      );

  String _text(DesignElement element) {
    final data = element.data;
    String value;
    if (element.type == DesignElementType.text) {
      value = data['text'] as String? ?? 'Text';
    } else if (element.type == DesignElementType.customFieldText) {
      final uuid = data['field_uuid'];
      value =
          student.customFields
              .where((field) => field.fieldUuid == uuid)
              .map((field) => field.value)
              .firstOrNull ??
          (data['fallback'] as String? ??
              data['label'] as String? ??
              'Custom field');
    } else {
      value = switch (data['field']) {
        'full_name' => student.fullName,
        'admission_no' => student.admissionNo,
        'roll_no' => student.rollNo ?? '',
        'stream' => student.stream ?? '',
        'father_name' => student.fatherName ?? '',
        'mother_name' => student.motherName ?? '',
        'dob' => _date(student.dob),
        'gender' => student.gender ?? '',
        'blood_group' => student.bloodGroup ?? '',
        'mobile' => student.mobile ?? '',
        'aadhaar' => student.aadhaar ?? '',
        'address' => student.address ?? '',
        'session' => sessionName ?? '',
        'class' => className ?? '',
        'section' => sectionName ?? '',
        _ => '',
      };
      if (value.isEmpty) value = data['fallback'] as String? ?? 'Student field';
    }
    return '${data['prefix'] ?? ''}$value${data['suffix'] ?? ''}';
  }

  String _date(DateTime? value) => value == null
      ? ''
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
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
