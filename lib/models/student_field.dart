class StudentFieldDefinition {
  const StudentFieldDefinition({
    required this.uuid,
    required this.fieldKey,
    required this.label,
    required this.dataType,
    required this.isRequired,
    required this.displayOrder,
    required this.isActive,
  });

  final String uuid;
  final String fieldKey;
  final String label;
  final String dataType;
  final bool isRequired;
  final int displayOrder;
  final bool isActive;

  factory StudentFieldDefinition.fromJson(Map<String, dynamic> json) =>
      StudentFieldDefinition(
        uuid: json['uuid'] as String,
        fieldKey: json['field_key'] as String,
        label: json['label'] as String,
        dataType: json['data_type'] as String,
        isRequired: json['is_required'] == true,
        displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] != false,
      );
}

class BuiltinStudentField {
  const BuiltinStudentField({
    required this.key,
    required this.label,
    required this.dataType,
    required this.enabled,
    required this.required,
    required this.protected,
    required this.displayOrder,
  });

  final String key;
  final String label;
  final String dataType;
  final bool enabled;
  final bool required;
  final bool protected;
  final int displayOrder;

  BuiltinStudentField copyWith({
    bool? enabled,
    bool? required,
    int? displayOrder,
  }) => BuiltinStudentField(
    key: key,
    label: label,
    dataType: dataType,
    enabled: enabled ?? this.enabled,
    required: required ?? this.required,
    protected: protected,
    displayOrder: displayOrder ?? this.displayOrder,
  );

  factory BuiltinStudentField.fromJson(Map<String, dynamic> json) =>
      BuiltinStudentField(
        key: json['key'] as String,
        label: json['label'] as String,
        dataType: json['data_type'] as String,
        enabled: json['enabled'] == true,
        required: json['required'] == true,
        protected: json['protected'] == true,
        displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'key': key,
    'enabled': enabled,
    'required': required,
    'display_order': displayOrder,
  };
}

class StudentCustomFieldValue {
  const StudentCustomFieldValue({
    required this.fieldUuid,
    required this.value,
    this.fieldKey,
    this.label,
    this.dataType,
    this.isActive = true,
  });

  final String fieldUuid;
  final String value;
  final String? fieldKey;
  final String? label;
  final String? dataType;
  final bool isActive;

  Map<String, dynamic> toJson() => {'field_uuid': fieldUuid, 'value': value};

  factory StudentCustomFieldValue.fromJson(Map<String, dynamic> json) =>
      StudentCustomFieldValue(
        fieldUuid: json['field_uuid'] as String,
        value: json['value'] as String? ?? '',
        fieldKey: json['field_key'] as String?,
        label: json['label'] as String?,
        dataType: json['data_type'] as String?,
        isActive: json['is_active'] != false,
      );
}
