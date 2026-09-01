class PublicFormConfig {
  const PublicFormConfig({
    this.uuid,
    this.publicToken,
    required this.title,
    this.instructions,
    this.isActive = false,
    this.requireAllFields = false,
    this.allowPhoto = false,
    this.expiresAt,
    this.selectedSystemFields = const [],
    this.selectedCustomFieldUuids = const [],
    this.successMessage,
  });
  final String? uuid;
  final String? publicToken;
  final String title;
  final String? instructions;
  final bool isActive;
  final bool requireAllFields;
  final bool allowPhoto;
  final DateTime? expiresAt;
  final List<String> selectedSystemFields;
  final List<String> selectedCustomFieldUuids;
  final String? successMessage;
  factory PublicFormConfig.fromJson(Map<String, dynamic> json) =>
      PublicFormConfig(
        uuid: json['uuid'] as String?,
        publicToken: json['public_token'] as String?,
        title: json['title'] as String? ?? 'Student information form',
        instructions: json['instructions'] as String?,
        isActive: json['is_active'] == true,
        requireAllFields: json['require_all_fields'] == true,
        allowPhoto: json['allow_photo'] == true,
        expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
        selectedSystemFields:
            (json['selected_system_fields'] as List<dynamic>? ?? [])
                .cast<String>(),
        selectedCustomFieldUuids:
            (json['selected_custom_field_uuids'] as List<dynamic>? ?? [])
                .cast<String>(),
        successMessage: json['success_message'] as String?,
      );
}

class PublicFormField {
  const PublicFormField({
    required this.key,
    required this.label,
    required this.dataType,
    required this.required,
    required this.kind,
    this.fieldUuid,
    this.options = const [],
  });
  final String key;
  final String label;
  final String dataType;
  final bool required;
  final String kind;
  final String? fieldUuid;
  final List<Map<String, String>> options;
  factory PublicFormField.fromJson(Map<String, dynamic> json) =>
      PublicFormField(
        key: json['key'] as String,
        label: json['label'] as String,
        dataType: json['data_type'] as String,
        required: json['required'] == true,
        kind: json['kind'] as String,
        fieldUuid: json['field_uuid'] as String?,
        options: (json['options'] as List<dynamic>? ?? [])
            .map((item) => Map<String, String>.from(item as Map))
            .toList(),
      );
}

class PublicFormView {
  const PublicFormView({
    required this.schoolName,
    this.schoolLogoUrl,
    required this.title,
    this.instructions,
    required this.fields,
    required this.allowPhoto,
    this.photoRequired = false,
    required this.maxPhotoSizeBytes,
    this.successMessage,
  });
  final String schoolName;
  final String? schoolLogoUrl;
  final String title;
  final String? instructions;
  final List<PublicFormField> fields;
  final bool allowPhoto;
  final bool photoRequired;
  final int maxPhotoSizeBytes;
  final String? successMessage;
  factory PublicFormView.fromJson(Map<String, dynamic> json) => PublicFormView(
    schoolName: json['school_name'] as String,
    schoolLogoUrl: json['school_logo_url'] as String?,
    title: json['title'] as String,
    instructions: json['instructions'] as String?,
    fields: (json['fields'] as List<dynamic>)
        .map((item) => PublicFormField.fromJson(item as Map<String, dynamic>))
        .toList(),
    allowPhoto: json['allow_photo'] == true,
    photoRequired: json['photo_required'] == true,
    maxPhotoSizeBytes: (json['max_photo_size_bytes'] as num).toInt(),
    successMessage: json['success_message'] as String?,
  );
}
