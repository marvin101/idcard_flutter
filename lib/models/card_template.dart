import 'dart:convert';

import 'package:flutter/material.dart';

enum DesignElementType {
  text,
  boundText,
  customFieldText,
  studentPhoto,
  schoolLogo,
  rectangle,
  line,
  qrCode,
}

extension DesignElementTypeWire on DesignElementType {
  String get wire => switch (this) {
    DesignElementType.boundText => 'bound_text',
    DesignElementType.customFieldText => 'custom_field_text',
    DesignElementType.studentPhoto => 'student_photo',
    DesignElementType.schoolLogo => 'school_logo',
    DesignElementType.qrCode => 'qr_code',
    _ => name,
  };
  static DesignElementType parse(Object? value) => switch (value) {
    'bound_text' => DesignElementType.boundText,
    'custom_field_text' => DesignElementType.customFieldText,
    'student_photo' => DesignElementType.studentPhoto,
    'school_logo' => DesignElementType.schoolLogo,
    'rectangle' => DesignElementType.rectangle,
    'line' => DesignElementType.line,
    'qr_code' => DesignElementType.qrCode,
    'text' => DesignElementType.text,
    _ => throw const FormatException(
      'Card-template element type is missing or unsupported.',
    ),
  };
}

@immutable
class DesignCanvas {
  const DesignCanvas({
    this.width = 85.6,
    this.height = 53.98,
    this.orientation = 'landscape',
    this.backgroundColor = '#FFFFFF',
    this.backgroundImage,
  });
  final double width, height;
  final String orientation, backgroundColor;
  final String? backgroundImage;
  factory DesignCanvas.fromJson(Map<String, dynamic> json) {
    final width = _requiredNumber(json, 'width', 'canvas.width');
    final height = _requiredNumber(json, 'height', 'canvas.height');
    final backgroundColor = json['background_color'];
    if (backgroundColor != null &&
        (backgroundColor is! String || !_isHex(backgroundColor))) {
      throw const FormatException(
        'Card-template canvas.background_color must be a hex color.',
      );
    }
    final backgroundImage = json['background_image'];
    if (backgroundImage != null && backgroundImage is! String) {
      throw const FormatException(
        'Card-template canvas.background_image must be a string or null.',
      );
    }
    return DesignCanvas(
      width: width,
      height: height,
      orientation: width >= height ? 'landscape' : 'portrait',
      backgroundColor: _safeHex(backgroundColor, '#FFFFFF'),
      backgroundImage: backgroundImage as String?,
    );
  }

  DesignCanvas copyWith({
    double? width,
    double? height,
    String? backgroundColor,
    String? backgroundImage,
  }) {
    final nextWidth = width ?? this.width;
    final nextHeight = height ?? this.height;
    return DesignCanvas(
      width: nextWidth,
      height: nextHeight,
      orientation: nextWidth >= nextHeight ? 'landscape' : 'portrait',
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundImage: backgroundImage ?? this.backgroundImage,
    );
  }

  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'orientation': orientation,
    'background_color': backgroundColor,
    'background_image': backgroundImage,
  };
}

@immutable
class DesignElement {
  const DesignElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.zIndex = 0,
    this.locked = false,
    this.visible = true,
    this.style = const {},
    this.data = const {},
  });
  final String id;
  final DesignElementType type;
  final double x, y, width, height, rotation;
  final int zIndex;
  final bool locked, visible;
  final Map<String, dynamic> style, data;
  factory DesignElement.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final zIndex = json['z_index'];
    final locked = json['locked'];
    final visible = json['visible'];
    final style = json['style'] ?? const <String, dynamic>{};
    final data = json['data'] ?? const <String, dynamic>{};
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException(
        'Card-template element id must be a non-empty string.',
      );
    }
    if (zIndex is! num || !zIndex.isFinite || zIndex.toInt() != zIndex) {
      throw const FormatException(
        'Card-template element z_index must be an integer.',
      );
    }
    if (locked is! bool || visible is! bool) {
      throw const FormatException(
        'Card-template element locked and visible must be booleans.',
      );
    }
    if (style is! Map || data is! Map) {
      throw const FormatException(
        'Card-template element style and data must be objects.',
      );
    }
    return DesignElement(
      id: id,
      type: DesignElementTypeWire.parse(json['type']),
      x: _requiredNumber(json, 'x', 'element.x'),
      y: _requiredNumber(json, 'y', 'element.y'),
      width: _requiredNumber(json, 'width', 'element.width'),
      height: _requiredNumber(json, 'height', 'element.height'),
      rotation: _requiredNumber(json, 'rotation', 'element.rotation'),
      zIndex: zIndex.toInt(),
      locked: locked,
      visible: visible,
      style: Map<String, dynamic>.from(style),
      data: Map<String, dynamic>.from(data),
    );
  }
  DesignElement copyWith({
    String? id,
    DesignElementType? type,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    int? zIndex,
    bool? locked,
    bool? visible,
    Map<String, dynamic>? style,
    Map<String, dynamic>? data,
  }) => DesignElement(
    id: id ?? this.id,
    type: type ?? this.type,
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
    zIndex: zIndex ?? this.zIndex,
    locked: locked ?? this.locked,
    visible: visible ?? this.visible,
    style: style ?? this.style,
    data: data ?? this.data,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.wire,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'rotation': rotation,
    'z_index': zIndex,
    'locked': locked,
    'visible': visible,
    'style': style,
    'data': data,
  };
}

@immutable
class DesignDocument {
  const DesignDocument({
    required this.canvas,
    required this.elements,
    this.settings = const {},
  }) : schemaVersion = currentSchemaVersion;
  static const currentSchemaVersion = 2;
  static const maxElements = 250;
  final int schemaVersion;
  final DesignCanvas canvas;
  final List<DesignElement> elements;
  final Map<String, dynamic> settings;
  factory DesignDocument.fromJson(Map<String, dynamic> json) {
    final version = json.containsKey('schema_version')
        ? json['schema_version']
        : json['version'] ?? 1;
    if (version == 1) return legacyDesignDocument(json);
    if (version != currentSchemaVersion) {
      throw FormatException(
        'Unsupported card-template schema_version: $version',
      );
    }
    final canvas = json['canvas'];
    final raw = json['elements'];
    final settings = json['settings'] ?? const <String, dynamic>{};
    if (canvas is! Map) {
      throw const FormatException(
        'Card-template v2 canvas is missing or invalid.',
      );
    }
    if (raw is! List) {
      throw const FormatException('Card-template v2 elements must be a list.');
    }
    if (settings is! Map) {
      throw const FormatException(
        'Card-template v2 settings must be an object.',
      );
    }
    return DesignDocument(
      canvas: DesignCanvas.fromJson(Map<String, dynamic>.from(canvas)),
      elements: raw.map((item) {
        if (item is! Map) {
          throw const FormatException(
            'Card-template v2 elements must be objects.',
          );
        }
        return DesignElement.fromJson(Map<String, dynamic>.from(item));
      }).toList(),
      settings: Map<String, dynamic>.from(settings),
    );
  }
  DesignDocument copyWith({
    DesignCanvas? canvas,
    List<DesignElement>? elements,
    Map<String, dynamic>? settings,
  }) => DesignDocument(
    canvas: canvas ?? this.canvas,
    elements: elements ?? this.elements,
    settings: settings ?? this.settings,
  );
  Map<String, dynamic> toJson() => {
    'schema_version': currentSchemaVersion,
    'canvas': canvas.toJson(),
    'elements': elements.map((e) => e.toJson()).toList(),
    'settings': settings,
  };
}

@immutable
class CardTemplate {
  const CardTemplate({
    required this.name,
    required this.document,
    this.backDocument,
    this.updatedAt,
  });
  static const maxNameLength = 120;
  final String name;
  final DesignDocument document;
  final DesignDocument? backDocument;
  final DateTime? updatedAt;
  static final uploadedDesign = CardTemplate(
    name: 'Uploaded blue school card',
    document: legacyDesignDocument(const {
      'school_title': 'ANITA INTERMEDIATE COLLEGE',
      'school_subtitle': 'Kanke, Ranchi',
      'primary_color': '#242C61',
      'accent_color': '#FFE000',
      'photo_border_color': '#00AEE8',
      'show_stream': true,
      'show_blood_group': true,
      'show_mobile': true,
      'show_address': true,
      'mask_aadhaar': true,
      'rounded_photo': true,
    }),
  );
  String get schoolTitle =>
      document.settings['legacy_school_title'] as String? ?? '';
  String get schoolSubtitle =>
      document.settings['legacy_school_subtitle'] as String? ?? '';
  Color get primaryColor => colorFromHex(
    document.settings['legacy_primary_color'],
    const Color(0xff242c61),
  );
  Color get accentColor => colorFromHex(
    document.settings['legacy_accent_color'],
    const Color(0xffffe000),
  );
  Color get photoBorderColor => colorFromHex(
    document.settings['legacy_photo_border_color'],
    const Color(0xff00aee8),
  );
  bool get showStream => document.settings['show_stream'] != false;
  bool get showBloodGroup => document.settings['show_blood_group'] != false;
  bool get showMobile => document.settings['show_mobile'] != false;
  bool get showAddress => document.settings['show_address'] != false;
  bool get maskAadhaar => document.settings['mask_aadhaar'] != false;
  bool get roundedPhoto => document.settings['rounded_photo'] != false;
  bool get hasBackDesign => backDocument != null;

  CardTemplate copyWith({
    String? name,
    DesignDocument? document,
    DesignDocument? backDocument,
    bool clearBackDocument = false,
  }) => CardTemplate(
    name: name ?? this.name,
    document: document ?? this.document,
    backDocument: clearBackDocument ? null : backDocument ?? this.backDocument,
    updatedAt: updatedAt,
  );

  /// Returns a structurally independent copy, including nested style, binding,
  /// and settings collections.
  CardTemplate deepCopy() => CardTemplate(
    name: name,
    updatedAt: updatedAt,
    document: DesignDocument.fromJson(
      Map<String, dynamic>.from(
        jsonDecode(jsonEncode(document.toJson())) as Map,
      ),
    ),
    backDocument: backDocument == null
        ? null
        : DesignDocument.fromJson(
            Map<String, dynamic>.from(
              jsonDecode(jsonEncode(backDocument!.toJson())) as Map,
            ),
          ),
  );

  /// Creates a local experiment whose element identities cannot collide with
  /// the source document. Persisted template identity is intentionally not
  /// represented here because the current API exposes one template per school.
  CardTemplate duplicateWorkingCopy({
    required String Function(DesignElement element, int index) elementId,
  }) {
    final deepCopied = deepCopy();
    final copied = deepCopied.document;
    final copiedBack = deepCopied.backDocument;
    return CardTemplate(
      name: '$name copy',
      document: copied.copyWith(
        elements: [
          for (var i = 0; i < copied.elements.length; i++)
            copied.elements[i].copyWith(id: elementId(copied.elements[i], i)),
        ],
      ),
      backDocument: copiedBack?.copyWith(
        elements: [
          for (var i = 0; i < copiedBack.elements.length; i++)
            copiedBack.elements[i].copyWith(
              id: elementId(copiedBack.elements[i], copied.elements.length + i),
            ),
        ],
      ),
    );
  }

  factory CardTemplate.fromApi(Map<String, dynamic> json) {
    final name = json['name'];
    final design = json['design'];
    final backDesign = json['back_design'];
    final rawUpdatedAt = json['updated_at'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Card-template name is missing or invalid.');
    }
    if (design is! Map) {
      throw const FormatException(
        'Card-template design is missing or invalid.',
      );
    }
    if (backDesign != null && backDesign is! Map) {
      throw const FormatException(
        'Card-template back_design must be an object or null.',
      );
    }
    final updatedAt = switch (rawUpdatedAt) {
      null => null,
      String value => DateTime.tryParse(value),
      _ => null,
    };
    final hasTimezone =
        rawUpdatedAt is String &&
        RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(rawUpdatedAt);
    if (rawUpdatedAt != null && (updatedAt == null || !hasTimezone)) {
      throw const FormatException(
        'Card-template updated_at is missing or invalid.',
      );
    }
    final frontDocument = DesignDocument.fromJson(
      Map<String, dynamic>.from(design),
    );
    final parsedBack = backDesign == null
        ? null
        : DesignDocument.fromJson(Map<String, dynamic>.from(backDesign));
    if (parsedBack != null &&
        ((parsedBack.canvas.width - frontDocument.canvas.width).abs() > .001 ||
            (parsedBack.canvas.height - frontDocument.canvas.height).abs() >
                .001)) {
      throw const FormatException(
        'Card-template front and back canvas dimensions must match.',
      );
    }
    return CardTemplate(
      name: name,
      document: frontDocument,
      backDocument: parsedBack,
      updatedAt: updatedAt?.toUtc(),
    );
  }
  Map<String, dynamic> toApi({DateTime? expectedUpdatedAt}) => {
    'name': name,
    'design': document.toJson(),
    'back_design': backDocument?.toJson(),
    if (expectedUpdatedAt != null)
      'expected_updated_at': expectedUpdatedAt.toUtc().toIso8601String(),
  };

  CardTemplate withBlankBack() => backDocument != null
      ? this
      : copyWith(
          backDocument: DesignDocument(
            canvas: DesignCanvas(
              width: document.canvas.width,
              height: document.canvas.height,
              orientation: document.canvas.orientation,
              backgroundColor: '#FFFFFF',
            ),
            elements: const [],
            settings: Map<String, dynamic>.from(document.settings),
          ),
        );
}

DesignDocument legacyDesignDocument(Map<String, dynamic> design) {
  final title = design['school_title'] as String? ?? 'SCHOOL NAME';
  final subtitle = design['school_subtitle'] as String? ?? 'School address';
  final primary = _safeHex(design['primary_color'], '#242C61');
  final accent = _safeHex(design['accent_color'], '#FFE000');
  final photoBorder = _safeHex(design['photo_border_color'], '#00AEE8');
  var z = 0;
  DesignElement e(
    String id,
    DesignElementType type,
    double x,
    double y,
    double w,
    double h, {
    Map<String, dynamic> style = const {},
    Map<String, dynamic> data = const {},
  }) => DesignElement(
    id: id,
    type: type,
    x: x,
    y: y,
    width: w,
    height: h,
    zIndex: z++,
    style: style,
    data: data,
  );
  final elements = <DesignElement>[
    e(
      'legacy-header',
      DesignElementType.rectangle,
      0,
      0,
      85.6,
      12,
      style: {
        'fill_color': primary,
        'border_color': primary,
        'border_width': 0.0,
        'corner_radius': 0.0,
      },
    ),
    e(
      'legacy-title',
      DesignElementType.text,
      4,
      2,
      77.6,
      5,
      style: {
        'font_size': 4.2,
        'font_weight': 900,
        'alignment': 'center',
        'color': accent,
      },
      data: {'text': title.toUpperCase()},
    ),
    e(
      'legacy-subtitle',
      DesignElementType.text,
      4,
      7,
      77.6,
      3,
      style: {
        'font_size': 2.4,
        'font_weight': 400,
        'alignment': 'center',
        'color': '#FFFFFF',
      },
      data: {'text': subtitle},
    ),
    e(
      'legacy-photo',
      DesignElementType.studentPhoto,
      31.8,
      14,
      22,
      25,
      style: {
        'fit': 'cover',
        'border_color': photoBorder,
        'border_width': 1.0,
        'corner_radius': design['rounded_photo'] == false ? 0.0 : 3.0,
      },
    ),
    e(
      'legacy-name',
      DesignElementType.boundText,
      22,
      40,
      42,
      4,
      style: {
        'font_size': 3.2,
        'font_weight': 900,
        'alignment': 'center',
        'color': '#E52B24',
      },
      data: {'field': 'full_name', 'fallback': 'Student name'},
    ),
    e(
      'legacy-admission',
      DesignElementType.boundText,
      4,
      28,
      24,
      4,
      style: {
        'font_size': 2.5,
        'font_weight': 700,
        'alignment': 'left',
        'color': '#222222',
      },
      data: {
        'field': 'admission_no',
        'prefix': 'Adm No: ',
        'fallback': 'Admission no.',
      },
    ),
    e(
      'legacy-father',
      DesignElementType.boundText,
      57,
      17,
      25,
      4,
      style: {
        'font_size': 2.4,
        'font_weight': 600,
        'alignment': 'left',
        'color': '#222222',
      },
      data: {
        'field': 'father_name',
        'prefix': 'Father: ',
        'fallback': "Father's name",
      },
    ),
    e(
      'legacy-dob',
      DesignElementType.boundText,
      57,
      22,
      25,
      4,
      style: {
        'font_size': 2.4,
        'font_weight': 600,
        'alignment': 'left',
        'color': '#222222',
      },
      data: {'field': 'dob', 'prefix': 'DOB: ', 'fallback': 'Date of birth'},
    ),
    e(
      'legacy-footer',
      DesignElementType.rectangle,
      0,
      48.5,
      85.6,
      5.48,
      style: {
        'fill_color': primary,
        'border_color': primary,
        'border_width': 0.0,
        'corner_radius': 0.0,
      },
    ),
    e(
      'legacy-signature',
      DesignElementType.text,
      61,
      49.5,
      21,
      3,
      style: {
        'font_size': 2.0,
        'font_weight': 600,
        'alignment': 'right',
        'color': '#FFFFFF',
      },
      data: {'text': 'Principal Sig.'},
    ),
  ];
  return DesignDocument(
    canvas: const DesignCanvas(),
    elements: elements,
    settings: {
      'grid_enabled': true,
      'grid_size': 2.0,
      'snap_enabled': true,
      'legacy_school_title': title,
      'legacy_school_subtitle': subtitle,
      'legacy_primary_color': primary,
      'legacy_accent_color': accent,
      'legacy_photo_border_color': photoBorder,
      'show_stream': design['show_stream'] != false,
      'show_blood_group': design['show_blood_group'] != false,
      'show_mobile': design['show_mobile'] != false,
      'show_address': design['show_address'] != false,
      'mask_aadhaar': design['mask_aadhaar'] != false,
      'rounded_photo': design['rounded_photo'] != false,
      'migrated_from_v1': true,
    },
  );
}

double _requiredNumber(Map<String, dynamic> values, String key, String label) {
  final value = values[key];
  if (value is! num || !value.isFinite) {
    throw FormatException('Card-template $label must be a finite number.');
  }
  return value.toDouble();
}

bool _isHex(String value) =>
    RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(value);
String _safeHex(Object? value, String fallback) =>
    value is String && _isHex(value) ? value.toUpperCase() : fallback;
Color colorFromHex(Object? value, Color fallback) {
  if (value is! String) return fallback;
  final hex = value.replaceFirst('#', '');
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null
      ? fallback
      : Color(hex.length == 6 ? 0xff000000 | parsed : parsed);
}

String colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
String maskAadhaarValue(String? value) {
  final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length <= 4) return digits;
  return '${List.filled(digits.length - 4, 'X').join()}${digits.substring(digits.length - 4)}';
}
