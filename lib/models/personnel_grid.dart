import 'api_personnel.dart';
import 'student_field.dart';

class PersonnelGridRow {
  const PersonnelGridRow({
    required this.uuid,
    required this.updatedAt,
    required this.personnelType,
    required this.systemFields,
    required this.customFields,
  });

  final String uuid;
  final DateTime updatedAt;
  final PersonnelType personnelType;
  final Map<String, String?> systemFields;
  final Map<String, String> customFields;

  factory PersonnelGridRow.fromJson(Map<String, dynamic> json) =>
      PersonnelGridRow(
        uuid: json['uuid'] as String,
        updatedAt: DateTime.parse(json['updated_at'] as String),
        personnelType: PersonnelType.values.byName(
          json['personnel_type'] as String,
        ),
        systemFields: {
          for (final key in const [
            'employee_no',
            'full_name',
            'designation',
            'department',
            'dob',
            'gender',
            'blood_group',
            'mobile',
            'email',
            'address',
          ])
            key: json[key]?.toString(),
        },
        customFields: Map<String, String>.from(
          json['custom_fields'] as Map? ?? const {},
        ),
      );
}

class PersonnelGridPage {
  const PersonnelGridPage({
    required this.rows,
    required this.total,
    required this.offset,
    required this.limit,
    required this.hasMore,
    required this.customFields,
    required this.departments,
    required this.designations,
  });

  final List<PersonnelGridRow> rows;
  final int total;
  final int offset;
  final int limit;
  final bool hasMore;
  final List<StudentFieldDefinition> customFields;
  final List<String> departments;
  final List<String> designations;

  factory PersonnelGridPage.fromJson(Map<String, dynamic> json) =>
      PersonnelGridPage(
        rows: (json['rows'] as List<dynamic>)
            .map(
              (item) => PersonnelGridRow.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        total: (json['total'] as num).toInt(),
        offset: (json['offset'] as num).toInt(),
        limit: (json['limit'] as num).toInt(),
        hasMore: json['has_more'] == true,
        customFields: (json['custom_fields'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  StudentFieldDefinition.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        departments: (json['departments'] as List<dynamic>? ?? const [])
            .cast<String>(),
        designations: (json['designations'] as List<dynamic>? ?? const [])
            .cast<String>(),
      );
}

class PersonnelGridRowPatch {
  const PersonnelGridRowPatch({
    required this.personnelUuid,
    required this.expectedUpdatedAt,
    required this.systemFields,
    required this.customFields,
  });

  final String personnelUuid;
  final DateTime expectedUpdatedAt;
  final Map<String, dynamic> systemFields;
  final Map<String, dynamic> customFields;

  Map<String, dynamic> toJson() => {
    'personnel_uuid': personnelUuid,
    'expected_updated_at': expectedUpdatedAt.toUtc().toIso8601String(),
    'system_fields': systemFields,
    'custom_fields': customFields,
  };
}

class PersonnelGridPatchResult {
  const PersonnelGridPatchResult({
    required this.updatedCount,
    required this.rows,
  });
  final int updatedCount;
  final List<PersonnelGridRow> rows;

  factory PersonnelGridPatchResult.fromJson(Map<String, dynamic> json) =>
      PersonnelGridPatchResult(
        updatedCount: (json['updated_count'] as num).toInt(),
        rows: (json['rows'] as List<dynamic>? ?? const [])
            .map(
              (item) => PersonnelGridRow.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}
