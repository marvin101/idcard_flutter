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

class StreamOption {
  const StreamOption({required this.name, required this.code});

  final String name;
  final String code;

  factory StreamOption.fromJson(Map<String, dynamic> json) => StreamOption(
    name: (json['name'] as String?)?.trim() ?? '',
    code: (json['code'] as String?)?.trim() ?? '',
  );

  Map<String, dynamic> toJson() => {'name': name, 'code': code};

  StreamOption copyWith({String? name, String? code}) => StreamOption(
    name: name ?? this.name,
    code: code ?? this.code,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamOption &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          code == other.code;

  @override
  int get hashCode => Object.hash(name, code);
}

class StudentFieldConfigResponse {
  const StudentFieldConfigResponse({
    required this.fields,
    this.autoAdmissionFormat = false,
    this.streamOptions = const [],
  });

  final List<BuiltinStudentField> fields;
  final bool autoAdmissionFormat;
  final List<StreamOption> streamOptions;

  factory StudentFieldConfigResponse.fromJson(Map<String, dynamic> json) =>
      StudentFieldConfigResponse(
        fields: (json['fields'] as List<dynamic>? ?? const [])
            .map((item) => BuiltinStudentField.fromJson(item as Map<String, dynamic>))
            .toList(),
        autoAdmissionFormat: json['auto_admission_format'] as bool? ?? false,
        streamOptions: (json['stream_options'] as List<dynamic>? ?? const [])
            .map((item) => StreamOption.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}
