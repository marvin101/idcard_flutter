import 'student_field.dart';

class StudentGridLookupItem {
  const StudentGridLookupItem({
    required this.uuid,
    required this.name,
    this.classUuid,
  });

  final String uuid;
  final String name;
  final String? classUuid;

  factory StudentGridLookupItem.fromJson(Map<String, dynamic> json) =>
      StudentGridLookupItem(
        uuid: json['uuid'] as String,
        name: json['name'] as String,
        classUuid: json['class_uuid'] as String?,
      );
}

class StudentGridRow {
  const StudentGridRow({
    required this.uuid,
    required this.updatedAt,
    required this.values,
    required this.customFields,
  });

  final String uuid;
  final DateTime updatedAt;
  final Map<String, String?> values;
  final Map<String, String> customFields;

  factory StudentGridRow.fromJson(Map<String, dynamic> json) {
    const fields = [
      'session_uuid',
      'class_uuid',
      'section_uuid',
      'admission_no',
      'roll_no',
      'stream',
      'full_name',
      'father_name',
      'mother_name',
      'dob',
      'gender',
      'blood_group',
      'mobile',
      'aadhaar',
      'address',
    ];
    return StudentGridRow(
      uuid: json['uuid'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      values: {for (final field in fields) field: json[field]?.toString()},
      customFields: (json['custom_fields'] as Map<String, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key, value?.toString() ?? '')),
    );
  }
}

class StudentGridPage {
  const StudentGridPage({
    required this.rows,
    required this.total,
    required this.offset,
    required this.limit,
    required this.hasMore,
    required this.customFields,
    required this.sessions,
    required this.classes,
    required this.sections,
  });

  final List<StudentGridRow> rows;
  final int total;
  final int offset;
  final int limit;
  final bool hasMore;
  final List<StudentFieldDefinition> customFields;
  final List<StudentGridLookupItem> sessions;
  final List<StudentGridLookupItem> classes;
  final List<StudentGridLookupItem> sections;

  factory StudentGridPage.fromJson(Map<String, dynamic> json) =>
      StudentGridPage(
        rows: (json['rows'] as List<dynamic>? ?? const [])
            .map(
              (item) => StudentGridRow.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        offset: (json['offset'] as num?)?.toInt() ?? 0,
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        hasMore: json['has_more'] == true,
        customFields: (json['custom_fields'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  StudentFieldDefinition.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        sessions: _lookups(json['sessions']),
        classes: _lookups(json['classes']),
        sections: _lookups(json['sections']),
      );

  static List<StudentGridLookupItem> _lookups(dynamic value) =>
      (value as List<dynamic>? ?? const [])
          .map(
            (item) =>
                StudentGridLookupItem.fromJson(item as Map<String, dynamic>),
          )
          .toList();
}

class StudentGridRowPatch {
  const StudentGridRowPatch({
    required this.studentUuid,
    required this.expectedUpdatedAt,
    required this.systemFields,
    required this.customFields,
  });

  final String studentUuid;
  final DateTime expectedUpdatedAt;
  final Map<String, dynamic> systemFields;
  final Map<String, dynamic> customFields;

  Map<String, dynamic> toJson() => {
    'student_uuid': studentUuid,
    'expected_updated_at': expectedUpdatedAt.toUtc().toIso8601String(),
    'system_fields': systemFields,
    'custom_fields': customFields,
  };
}

class StudentGridPatchResult {
  const StudentGridPatchResult({
    required this.updatedCount,
    required this.rows,
  });

  final int updatedCount;
  final List<StudentGridRow> rows;

  factory StudentGridPatchResult.fromJson(Map<String, dynamic> json) =>
      StudentGridPatchResult(
        updatedCount: (json['updated_count'] as num?)?.toInt() ?? 0,
        rows: (json['rows'] as List<dynamic>? ?? const [])
            .map(
              (item) => StudentGridRow.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class StudentGridCellError {
  const StudentGridCellError({
    required this.studentUuid,
    required this.field,
    required this.message,
  });

  final String studentUuid;
  final String field;
  final String message;

  factory StudentGridCellError.fromJson(Map<String, dynamic> json) =>
      StudentGridCellError(
        studentUuid: json['student_uuid']?.toString() ?? '',
        field: json['field']?.toString() ?? 'grid',
        message: json['message']?.toString() ?? 'Invalid value',
      );
}
