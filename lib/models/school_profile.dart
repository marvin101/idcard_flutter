class SchoolProfile {
  const SchoolProfile({
    required this.uuid,
    required this.schoolCode,
    required this.schoolName,
    this.email,
    this.phone,
    this.website,
    this.address,
    this.city,
    this.district,
    this.state,
    this.country,
    this.postalCode,
    this.logoPath,
    this.logoUrl,
    this.principalName,
    required this.isActive,
  });

  final String uuid;
  final String schoolCode;
  final String schoolName;
  final String? email;
  final String? phone;
  final String? website;
  final String? address;
  final String? city;
  final String? district;
  final String? state;
  final String? country;
  final String? postalCode;
  final String? logoPath;
  final String? logoUrl;
  final String? principalName;
  final bool isActive;

  factory SchoolProfile.fromJson(Map<String, dynamic> json) => SchoolProfile(
    uuid: json['uuid'] as String,
    schoolCode: json['school_code'] as String,
    schoolName: json['school_name'] as String,
    email: json['email'] as String?,
    phone: json['phone'] as String?,
    website: json['website'] as String?,
    address: json['address'] as String?,
    city: json['city'] as String?,
    district: json['district'] as String?,
    state: json['state'] as String?,
    country: json['country'] as String?,
    postalCode: json['postal_code'] as String?,
    logoPath: json['logo_path'] as String?,
    logoUrl: json['logo_url'] as String?,
    principalName: json['principal_name'] as String?,
    isActive: json['is_active'] as bool? ?? true,
  );

  Map<String, dynamic> toUpdateJson() => {
    'school_name': schoolName.trim(),
    'email': _emptyToNull(email),
    'phone': _emptyToNull(phone),
    'website': _emptyToNull(website),
    'address': _emptyToNull(address),
    'city': _emptyToNull(city),
    'district': _emptyToNull(district),
    'state': _emptyToNull(state),
    'country': _emptyToNull(country),
    'postal_code': _emptyToNull(postalCode),
    'principal_name': _emptyToNull(principalName),
  };

  SchoolProfile copyWith({
    String? schoolName,
    String? email,
    String? phone,
    String? website,
    String? address,
    String? city,
    String? district,
    String? state,
    String? country,
    String? postalCode,
    String? principalName,
  }) => SchoolProfile(
    uuid: uuid,
    schoolCode: schoolCode,
    schoolName: schoolName ?? this.schoolName,
    email: email,
    phone: phone,
    website: website,
    address: address,
    city: city,
    district: district,
    state: state,
    country: country,
    postalCode: postalCode,
    logoPath: logoPath,
    logoUrl: logoUrl,
    principalName: principalName,
    isActive: isActive,
  );

  static String? _emptyToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
