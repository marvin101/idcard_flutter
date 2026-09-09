import 'dart:convert';

import 'api_student.dart';
import 'card_template.dart';
import 'school_profile.dart';

/// Content substitution shared by the editor, student previews and PDF output.
/// Bindings never supply placement or styling: those belong to DesignElement.
class DesignBindings {
  const DesignBindings({
    required this.student,
    this.sessionName,
    this.className,
    this.sectionName,
    this.schoolName,
    this.schoolProfile,
  });
  final ApiStudent student;
  final String? sessionName, className, sectionName, schoolName;
  final SchoolProfile? schoolProfile;

  /// The bound value before a template fallback, prefix, or suffix is applied.
  ///
  /// Export preflight uses this same resolver so warnings cannot drift from the
  /// values rendered by previews and PDFs.
  String rawValue(DesignElement element) {
    final data = element.data;
    if (element.type == DesignElementType.text) {
      return data['text'] as String? ?? 'Text';
    }
    if (element.type == DesignElementType.qrCode && data['text'] is String) {
      return data['text'] as String;
    }
    return _rawBinding(data);
  }

  String _rawBinding(Map<String, dynamic> data) {
    if (data['field_uuid'] is String) {
      return student.customFields
              .where((field) => field.fieldUuid == data['field_uuid'])
              .map((field) => field.value)
              .firstOrNull ??
          '';
    }

    return switch (data['field']) {
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
      'school_name' => schoolProfile?.schoolName ?? schoolName ?? '',
      'school_address' => schoolProfile?.address ?? '',
      'school_code' => schoolProfile?.schoolCode ?? '',
      'school_phone' => schoolProfile?.phone ?? '',
      'school_email' => schoolProfile?.email ?? '',
      'school_website' => schoolProfile?.website ?? '',
      'school_city' => schoolProfile?.city ?? '',
      'school_district' => schoolProfile?.district ?? '',
      'school_state' => schoolProfile?.state ?? '',
      'school_country' => schoolProfile?.country ?? '',
      'school_postal_code' => schoolProfile?.postalCode ?? '',
      'principal_name' => schoolProfile?.principalName ?? '',
      _ => '',
    };
  }

  List<DesignQrFieldValue> qrFieldValues(DesignElement element) {
    final fields = element.data['fields'];
    if (element.type != DesignElementType.qrCode || fields is! List) {
      return const [];
    }
    return fields.whereType<Map>().map((source) {
      final binding = Map<String, dynamic>.from(source);
      final field = binding['field'] as String?;
      final fieldUuid = binding['field_uuid'] as String?;
      final key = field ?? 'custom:$fieldUuid';
      final label = binding['label'] as String? ?? field ?? 'Custom field';
      final raw = _rawBinding(binding);
      final fallback = binding['fallback'] as String? ?? '';
      return DesignQrFieldValue(
        key: key,
        label: label,
        rawValue: raw,
        value: raw.isEmpty ? fallback : raw,
      );
    }).toList();
  }

  String text(DesignElement element) {
    final data = element.data;
    if (element.type == DesignElementType.qrCode && data['fields'] is List) {
      final values = qrFieldValues(element);
      final payload = data['format'] == 'labeled_text'
          ? values.map((entry) => '${entry.label}: ${entry.value}').join('\n')
          : jsonEncode({for (final entry in values) entry.key: entry.value});
      return '${data['prefix'] ?? ''}$payload${data['suffix'] ?? ''}';
    }
    var value = rawValue(element);
    if (value.isEmpty && element.type != DesignElementType.text) {
      value = element.type == DesignElementType.customFieldText
          ? data['fallback'] as String? ??
                data['label'] as String? ??
                'Custom field'
          : element.type == DesignElementType.qrCode
          ? data['fallback'] as String? ?? 'QR data'
          : data['fallback'] as String? ?? 'Student field';
    }
    return '${data['prefix'] ?? ''}$value${data['suffix'] ?? ''}';
  }

  static String _date(DateTime? value) => value == null
      ? ''
      : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class DesignQrFieldValue {
  const DesignQrFieldValue({
    required this.key,
    required this.label,
    required this.rawValue,
    required this.value,
  });

  final String key;
  final String label;
  final String rawValue;
  final String value;
}

String? resolveDesignAssetUrl(String? path, String? baseUrl) {
  final value = path?.trim();
  if (value == null || value.isEmpty) return null;
  if (Uri.tryParse(value)?.hasScheme == true || baseUrl == null) return value;
  return Uri.parse(
    '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/',
  ).resolve(value).toString();
}
