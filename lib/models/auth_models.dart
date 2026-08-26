class AuthUser {
  const AuthUser({
    required this.uuid,
    required this.username,
    required this.fullName,
    this.email,
    this.mobile,
    this.designation,
    this.platformRole,
    required this.isPlatformAdmin,
    required this.isActive,
  });

  final String uuid;
  final String username;
  final String fullName;
  final String? email;
  final String? mobile;
  final String? designation;
  final String? platformRole;
  final bool isPlatformAdmin;
  final bool isActive;

  bool get isPlatformAdministrator =>
      platformRole == 'platform_admin' || isPlatformAdmin;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    uuid: json['uuid'] as String,
    username: json['username'] as String,
    fullName: json['full_name'] as String,
    email: json['email'] as String?,
    mobile: json['mobile'] as String?,
    designation: json['designation'] as String?,
    platformRole: json['platform_role'] as String?,
    isPlatformAdmin: json['is_platform_admin'] as bool? ?? false,
    isActive: json['is_active'] as bool? ?? true,
  );
}

class SchoolSummary {
  const SchoolSummary({
    required this.uuid,
    required this.code,
    required this.name,
    required this.isActive,
  });

  final String uuid;
  final String code;
  final String name;
  final bool isActive;

  factory SchoolSummary.fromJson(Map<String, dynamic> json) => SchoolSummary(
    uuid: json['uuid'] as String,
    code: json['school_code'] as String,
    name: json['school_name'] as String,
    isActive: json['is_active'] as bool? ?? true,
  );
}

class SchoolAccess {
  const SchoolAccess({
    required this.schoolUuid,
    required this.schoolName,
    required this.role,
  });

  final String schoolUuid;
  final String schoolName;
  final String role;

  bool get isSchoolAdministrator => role == 'school_admin' || role == 'admin';
  bool get isCardOperator => role == 'card_operator';

  factory SchoolAccess.fromJson(Map<String, dynamic> json) => SchoolAccess(
    schoolUuid: json['school_uuid'] as String,
    schoolName: json['school_name'] as String,
    role: json['role'] as String,
  );
}
