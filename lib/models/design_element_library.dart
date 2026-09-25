import 'dart:math' as math;

import 'card_template.dart';

/// Immutable catalog for every element Designer v2 can create.
///
/// Keeping defaults and physical constraints here prevents the toolbar,
/// inspector and gesture code from slowly developing different contracts.
class DesignElementDefinition {
  const DesignElementDefinition({
    required this.type,
    required this.label,
    required this.category,
    required this.width,
    required this.height,
    required this.minimumWidth,
    required this.minimumHeight,
    this.fixedAspectRatio,
    this.style = const {},
    this.data = const {},
  });

  final DesignElementType type;
  final String label;
  final String category;
  final double width;
  final double height;
  final double minimumWidth;
  final double minimumHeight;
  final double? fixedAspectRatio;
  final Map<String, dynamic> style;
  final Map<String, dynamic> data;
}

class DesignElementLibrary {
  const DesignElementLibrary._();

  static const definitions = <DesignElementDefinition>[
    DesignElementDefinition(
      type: DesignElementType.text,
      label: 'Text',
      category: 'Text & data',
      width: 30,
      height: 6,
      minimumWidth: 2,
      minimumHeight: 1,
      style: _textStyle,
      data: {'text': 'New text'},
    ),
    DesignElementDefinition(
      type: DesignElementType.boundText,
      label: 'Identity field',
      category: 'Text & data',
      width: 30,
      height: 6,
      minimumWidth: 2,
      minimumHeight: 1,
      style: _textStyle,
      data: {'field': 'full_name', 'fallback': 'Identity name'},
    ),
    DesignElementDefinition(
      type: DesignElementType.customFieldText,
      label: 'Custom field',
      category: 'Text & data',
      width: 30,
      height: 6,
      minimumWidth: 2,
      minimumHeight: 1,
      style: _textStyle,
    ),
    DesignElementDefinition(
      type: DesignElementType.studentPhoto,
      label: 'Photo',
      category: 'Media',
      width: 20,
      height: 22,
      minimumWidth: 2,
      minimumHeight: 1,
      style: {..._imageStyle, 'fit': 'cover'},
    ),
    DesignElementDefinition(
      type: DesignElementType.schoolLogo,
      label: 'Logo',
      category: 'Media',
      width: 20,
      height: 22,
      minimumWidth: 2,
      minimumHeight: 1,
      style: {..._imageStyle, 'fit': 'contain'},
    ),
    DesignElementDefinition(
      type: DesignElementType.principalSignature,
      label: 'Signature',
      category: 'Media',
      width: 20,
      height: 22,
      minimumWidth: 2,
      minimumHeight: 1,
      style: {..._imageStyle, 'fit': 'contain'},
    ),
    DesignElementDefinition(
      type: DesignElementType.rectangle,
      label: 'Rectangle',
      category: 'Shapes',
      width: 30,
      height: 6,
      minimumWidth: 2,
      minimumHeight: 1,
      style: _shapeStyle,
    ),
    DesignElementDefinition(
      type: DesignElementType.line,
      label: 'Line',
      category: 'Shapes',
      width: 30,
      height: 1,
      minimumWidth: 2,
      minimumHeight: 1,
      style: {'color': '#242C61', 'border_width': .5},
    ),
    DesignElementDefinition(
      type: DesignElementType.roundedRectangle,
      label: 'Rounded rectangle',
      category: 'Shapes',
      width: 30,
      height: 16,
      minimumWidth: 2,
      minimumHeight: 1,
      style: {
        'fill_color': '#E8EEF8',
        'border_color': '#242C61',
        'border_width': .5,
        'corner_radius': 3.0,
      },
    ),
    DesignElementDefinition(
      type: DesignElementType.ellipse,
      label: 'Ellipse',
      category: 'Shapes',
      width: 30,
      height: 16,
      minimumWidth: 2,
      minimumHeight: 1,
      style: _shapeStyle,
    ),
    DesignElementDefinition(
      type: DesignElementType.circle,
      label: 'Circle',
      category: 'Shapes',
      width: 20,
      height: 20,
      minimumWidth: 2,
      minimumHeight: 2,
      fixedAspectRatio: 1,
      style: _shapeStyle,
    ),
    DesignElementDefinition(
      type: DesignElementType.triangle,
      label: 'Triangle',
      category: 'Shapes',
      width: 30,
      height: 16,
      minimumWidth: 2,
      minimumHeight: 1,
      style: _shapeStyle,
    ),
    DesignElementDefinition(
      type: DesignElementType.bloodDrop,
      label: 'Blood group',
      category: 'Shapes',
      width: 20,
      height: 20,
      minimumWidth: 2,
      minimumHeight: 1,
      style: {
        'fill_color': '#C62828',
        'border_color': '#C62828',
        'border_width': .5,
        'corner_radius': 0.0,
      },
      data: {'field': 'blood_group', 'fallback': 'BG'},
    ),
    DesignElementDefinition(
      type: DesignElementType.qrCode,
      label: 'QR code',
      category: 'Codes',
      width: 20,
      height: 20,
      minimumWidth: 12,
      minimumHeight: 12,
      fixedAspectRatio: 1,
      style: {
        'color': '#000000',
        'background_color': '#FFFFFF',
        'quiet_zone': 1.0,
        'error_correction': 'medium',
      },
      data: {'field': 'verification_url'},
    ),
    DesignElementDefinition(
      type: DesignElementType.barcode,
      label: 'Barcode',
      category: 'Codes',
      width: 35,
      height: 15,
      minimumWidth: 25,
      minimumHeight: 10,
      style: {
        'color': '#000000',
        'background_color': '#FFFFFF',
        'quiet_zone': 1.0,
        'show_text': true,
        'font_size': 2.5,
      },
      data: {
        'field': 'admission_no',
        'fallback': 'Admission number',
        'symbology': 'code128',
      },
    ),
  ];

  static const _textStyle = <String, dynamic>{
    'font_size': 3.5,
    'font_weight': 400,
    'alignment': 'left',
    'color': '#111111',
  };
  static const _imageStyle = <String, dynamic>{
    'border_color': '#242C61',
    'border_width': .5,
    'corner_radius': 1.0,
  };
  static const _shapeStyle = <String, dynamic>{
    'fill_color': '#E8EEF8',
    'border_color': '#242C61',
    'border_width': .5,
    'corner_radius': 0.0,
  };

  static DesignElementDefinition definition(DesignElementType type) =>
      definitions.singleWhere((item) => item.type == type);

  static bool fitsCanvas(DesignElementType type, DesignCanvas canvas) {
    final item = definition(type);
    return canvas.width >= item.minimumWidth &&
        canvas.height >= item.minimumHeight;
  }

  static DesignElement create({
    required DesignElementType type,
    required String id,
    required int zIndex,
    required DesignCanvas canvas,
    String identityType = 'student',
    String? customFieldUuid,
    String? customFieldLabel,
  }) {
    final item = definition(type);
    if (!fitsCanvas(type, canvas)) {
      throw ArgumentError(
        '${item.label} requires a canvas of at least '
        '${item.minimumWidth} × ${item.minimumHeight} mm.',
      );
    }
    final width = math.min(item.width, canvas.width);
    final height = math.min(item.height, canvas.height);
    var data = Map<String, dynamic>.from(item.data);
    if (type == DesignElementType.boundText) {
      data['fallback'] = '$identityType name';
    } else if (type == DesignElementType.customFieldText) {
      if (customFieldUuid == null || customFieldLabel == null) {
        throw ArgumentError(
          'Custom-field elements require a field UUID and label.',
        );
      }
      data = {
        'field_uuid': customFieldUuid,
        'label': customFieldLabel,
        'fallback': customFieldLabel,
      };
    } else if (identityType != 'student' && type == DesignElementType.qrCode) {
      data = {'field': 'employee_no', 'fallback': 'Employee number'};
    } else if (identityType != 'student' && type == DesignElementType.barcode) {
      data = {...data, 'field': 'employee_no', 'fallback': 'Employee number'};
    }
    return DesignElement(
      id: id,
      type: type,
      x: (canvas.width - width) / 2,
      y: (canvas.height - height) / 2,
      width: width,
      height: height,
      zIndex: zIndex,
      style: Map<String, dynamic>.from(item.style),
      data: data,
    );
  }
}
