// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class CardTemplate {
  const CardTemplate({
    required this.name,
    required this.schoolTitle,
    required this.schoolSubtitle,
    required this.primaryColor,
    required this.accentColor,
    required this.photoBorderColor,
    required this.showStream,
    required this.showBloodGroup,
    required this.showMobile,
    required this.showAddress,
    required this.maskAadhaar,
    required this.roundedPhoto,
  });

  final String name;
  final String schoolTitle;
  final String schoolSubtitle;
  final Color primaryColor;
  final Color accentColor;
  final Color photoBorderColor;
  final bool showStream;
  final bool showBloodGroup;
  final bool showMobile;
  final bool showAddress;
  final bool maskAadhaar;
  final bool roundedPhoto;

  static const uploadedDesign = CardTemplate(
    name: 'Uploaded blue school card',
    schoolTitle: 'ANITA INTERMEDIATE COLLEGE',
    schoolSubtitle: 'Kanke, Ranchi',
    primaryColor: Color(0xff242c61),
    accentColor: Color(0xffffe000),
    photoBorderColor: Color(0xff00aee8),
    showStream: true,
    showBloodGroup: true,
    showMobile: true,
    showAddress: true,
    maskAadhaar: true,
    roundedPhoto: true,
  );

  CardTemplate copyWith({
    String? name,
    String? schoolTitle,
    String? schoolSubtitle,
    Color? primaryColor,
    Color? accentColor,
    Color? photoBorderColor,
    bool? showStream,
    bool? showBloodGroup,
    bool? showMobile,
    bool? showAddress,
    bool? maskAadhaar,
    bool? roundedPhoto,
  }) => CardTemplate(
    name: name ?? this.name,
    schoolTitle: schoolTitle ?? this.schoolTitle,
    schoolSubtitle: schoolSubtitle ?? this.schoolSubtitle,
    primaryColor: primaryColor ?? this.primaryColor,
    accentColor: accentColor ?? this.accentColor,
    photoBorderColor: photoBorderColor ?? this.photoBorderColor,
    showStream: showStream ?? this.showStream,
    showBloodGroup: showBloodGroup ?? this.showBloodGroup,
    showMobile: showMobile ?? this.showMobile,
    showAddress: showAddress ?? this.showAddress,
    maskAadhaar: maskAadhaar ?? this.maskAadhaar,
    roundedPhoto: roundedPhoto ?? this.roundedPhoto,
  );

  factory CardTemplate.fromApi(Map<String, dynamic> json) {
    final design =
        (json['design'] as Map?)?.cast<String, dynamic>() ?? const {};
    final fallback = uploadedDesign;
    return CardTemplate(
      name: json['name'] as String? ?? fallback.name,
      schoolTitle: design['school_title'] as String? ?? fallback.schoolTitle,
      schoolSubtitle:
          design['school_subtitle'] as String? ?? fallback.schoolSubtitle,
      primaryColor: _color(design['primary_color'], fallback.primaryColor),
      accentColor: _color(design['accent_color'], fallback.accentColor),
      photoBorderColor: _color(
        design['photo_border_color'],
        fallback.photoBorderColor,
      ),
      showStream: design['show_stream'] as bool? ?? fallback.showStream,
      showBloodGroup:
          design['show_blood_group'] as bool? ?? fallback.showBloodGroup,
      showMobile: design['show_mobile'] as bool? ?? fallback.showMobile,
      showAddress: design['show_address'] as bool? ?? fallback.showAddress,
      maskAadhaar: design['mask_aadhaar'] as bool? ?? fallback.maskAadhaar,
      roundedPhoto: design['rounded_photo'] as bool? ?? fallback.roundedPhoto,
    );
  }

  Map<String, dynamic> toApi() => {
    'name': name,
    'design': {
      'version': 1,
      'school_title': schoolTitle,
      'school_subtitle': schoolSubtitle,
      'primary_color': _hex(primaryColor),
      'accent_color': _hex(accentColor),
      'photo_border_color': _hex(photoBorderColor),
      'show_stream': showStream,
      'show_blood_group': showBloodGroup,
      'show_mobile': showMobile,
      'show_address': showAddress,
      'mask_aadhaar': maskAadhaar,
      'rounded_photo': roundedPhoto,
    },
  };

  static Color _color(Object? value, Color fallback) {
    if (value is! String) return fallback;
    final hex = value.replaceFirst('#', '');
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return fallback;
    return Color(hex.length == 6 ? 0xff000000 | parsed : parsed);
  }

  static String _hex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
}

String maskAadhaarValue(String? value) {
  final digits = value?.replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length <= 4) return digits;
  final masked = List.filled(digits.length - 4, 'X').join();
  return '$masked${digits.substring(digits.length - 4)}';
}
