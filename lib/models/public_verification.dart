class PublicVerificationFieldOption {
  const PublicVerificationFieldOption({required this.key, required this.label});

  final String key;
  final String label;

  factory PublicVerificationFieldOption.fromJson(Map<String, dynamic> json) =>
      PublicVerificationFieldOption(
        key: json['key'] as String,
        label: json['label'] as String,
      );
}

class PublicVerificationSettings {
  const PublicVerificationSettings({
    required this.enabled,
    required this.fields,
    required this.availableFields,
  });

  final bool enabled;
  final List<String> fields;
  final List<PublicVerificationFieldOption> availableFields;

  factory PublicVerificationSettings.fromJson(Map<String, dynamic> json) =>
      PublicVerificationSettings(
        enabled: json['enabled'] == true,
        fields: (json['fields'] as List<dynamic>).cast<String>(),
        availableFields:
            (json['available_fields'] as List<dynamic>? ?? const [])
                .map(
                  (item) => PublicVerificationFieldOption.fromJson(
                    item as Map<String, dynamic>,
                  ),
                )
                .toList(),
      );
}

class PublicVerificationValue {
  const PublicVerificationValue({
    required this.key,
    required this.label,
    required this.value,
  });

  final String key;
  final String label;
  final String value;

  factory PublicVerificationValue.fromJson(Map<String, dynamic> json) =>
      PublicVerificationValue(
        key: json['key'] as String,
        label: json['label'] as String,
        value: json['value'] as String,
      );
}

class PublicStudentVerification {
  const PublicStudentVerification({
    required this.schoolName,
    required this.schoolCode,
    required this.verificationStatus,
    required this.lifecycleStatus,
    required this.fields,
    this.logoUrl,
    this.photoUrl,
    this.verifiedAt,
  });

  final String schoolName;
  final String schoolCode;
  final String? logoUrl;
  final String verificationStatus;
  final String lifecycleStatus;
  final DateTime? verifiedAt;
  final String? photoUrl;
  final List<PublicVerificationValue> fields;

  bool get verified => verificationStatus == 'verified';

  factory PublicStudentVerification.fromJson(Map<String, dynamic> json) {
    final school = json['school'] as Map<String, dynamic>;
    return PublicStudentVerification(
      schoolName: school['school_name'] as String,
      schoolCode: school['school_code'] as String,
      logoUrl: school['logo_url'] as String?,
      verificationStatus: json['verification_status'] as String,
      lifecycleStatus: json['lifecycle_status'] as String,
      verifiedAt: json['verified_at'] is String
          ? DateTime.tryParse(json['verified_at'] as String)
          : null,
      photoUrl: json['photo_url'] as String?,
      fields: (json['fields'] as List<dynamic>)
          .map(
            (item) =>
                PublicVerificationValue.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class StudentVerificationLink {
  const StudentVerificationLink({required this.enabled, this.verificationUrl});

  final bool enabled;
  final String? verificationUrl;

  factory StudentVerificationLink.fromJson(Map<String, dynamic> json) =>
      StudentVerificationLink(
        enabled: json['enabled'] == true,
        verificationUrl: json['verification_url'] as String?,
      );
}
