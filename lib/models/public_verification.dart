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
    this.validityDays = 365,
  });

  final bool enabled;
  final List<String> fields;
  final List<PublicVerificationFieldOption> availableFields;
  final int validityDays;

  factory PublicVerificationSettings.fromJson(Map<String, dynamic> json) =>
      PublicVerificationSettings(
        enabled: json['enabled'] == true,
        validityDays: json['validity_days'] as int? ?? 365,
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
    this.credentialStatus = 'active',
    this.credentialVersion = 1,
    this.credentialIssuedAt,
    this.credentialExpiresAt,
    this.signatureVerified = false,
  });

  final String schoolName;
  final String schoolCode;
  final String? logoUrl;
  final String verificationStatus;
  final String lifecycleStatus;
  final DateTime? verifiedAt;
  final String? photoUrl;
  final List<PublicVerificationValue> fields;
  final String credentialStatus;
  final int credentialVersion;
  final DateTime? credentialIssuedAt;
  final DateTime? credentialExpiresAt;
  final bool signatureVerified;

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
      credentialStatus: json['credential_status'] as String? ?? 'active',
      credentialVersion: json['credential_version'] as int? ?? 1,
      credentialIssuedAt: json['credential_issued_at'] is String
          ? DateTime.tryParse(json['credential_issued_at'] as String)
          : null,
      credentialExpiresAt: json['credential_expires_at'] is String
          ? DateTime.tryParse(json['credential_expires_at'] as String)
          : null,
      signatureVerified: json['signature_verified'] == true,
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
  const StudentVerificationLink({
    required this.enabled,
    this.verificationUrl,
    this.credentialStatus = 'active',
    this.credentialVersion = 1,
    this.issuedAt,
    this.expiresAt,
  });

  final bool enabled;
  final String? verificationUrl;
  final String credentialStatus;
  final int credentialVersion;
  final DateTime? issuedAt;
  final DateTime? expiresAt;

  factory StudentVerificationLink.fromJson(Map<String, dynamic> json) =>
      StudentVerificationLink(
        enabled: json['enabled'] == true,
        verificationUrl: json['verification_url'] as String?,
        credentialStatus: json['credential_status'] as String? ?? 'active',
        credentialVersion: json['credential_version'] as int? ?? 1,
        issuedAt: json['issued_at'] is String
            ? DateTime.tryParse(json['issued_at'] as String)
            : null,
        expiresAt: json['expires_at'] is String
            ? DateTime.tryParse(json['expires_at'] as String)
            : null,
      );
}
