class AuthUser {
  const AuthUser({
    required this.uuid,
    required this.username,
    required this.fullName,
    this.email,
    this.mobile,
    this.designation,
    this.platformRole,
    this.profilePhotoUrl,
    this.lastLogin,
    this.createdAt,
    this.updatedAt,
    this.schoolContexts = const [],
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
  final String? profilePhotoUrl;
  final DateTime? lastLogin;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ProfileSchoolContext> schoolContexts;
  final bool isPlatformAdmin;
  final bool isActive;

  bool get isPlatformAdministrator =>
      platformRole == 'platform_admin' || isPlatformAdmin;

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return username.isEmpty ? '?' : username[0].toUpperCase();
    }
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    uuid: json['uuid'] as String,
    username: json['username'] as String,
    fullName: json['full_name'] as String,
    email: json['email'] as String?,
    mobile: json['mobile'] as String?,
    designation: json['designation'] as String?,
    platformRole: json['platform_role'] as String?,
    profilePhotoUrl: json['profile_photo_url'] as String?,
    lastLogin: DateTime.tryParse(json['last_login'] as String? ?? ''),
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
    schoolContexts: (json['school_contexts'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ProfileSchoolContext.fromJson)
        .toList(),
    isPlatformAdmin: json['is_platform_admin'] as bool? ?? false,
    isActive: json['is_active'] as bool? ?? true,
  );
}

class ProfileSchoolContext {
  const ProfileSchoolContext({
    required this.schoolUuid,
    required this.schoolName,
    required this.role,
  });

  final String schoolUuid;
  final String schoolName;
  final String role;

  factory ProfileSchoolContext.fromJson(Map<String, dynamic> json) =>
      ProfileSchoolContext(
        schoolUuid: json['school_uuid'] as String,
        schoolName: json['school_name'] as String,
        role: json['role'] as String,
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

class LifecyclePermissions {
  const LifecyclePermissions({
    required this.canVerify,
    required this.canViewHistory,
    required this.canMarkPrinted,
  });

  final bool canVerify;
  final bool canViewHistory;
  final bool canMarkPrinted;
}

LifecyclePermissions lifecyclePermissionsFor({
  required bool isPlatformAdmin,
  required String? schoolRole,
}) {
  final isSchoolAdmin = schoolRole == 'school_admin' || schoolRole == 'admin';
  final isAdministrator = isPlatformAdmin || isSchoolAdmin;
  return LifecyclePermissions(
    canVerify: isAdministrator,
    canViewHistory: isAdministrator,
    canMarkPrinted: isAdministrator || schoolRole == 'card_operator',
  );
}


class SecurityEvent {
  const SecurityEvent({
    required this.uuid,
    required this.eventType,
    required this.createdAt,
    this.ipAddress,
    this.userAgent,
    this.details = const {},
  });

  final String uuid;
  final String eventType;
  final DateTime createdAt;
  final String? ipAddress;
  final String? userAgent;
  final Map<String, dynamic> details;

  factory SecurityEvent.fromJson(Map<String, dynamic> json) => SecurityEvent(
    uuid: json['uuid'] as String,
    eventType: json['event_type'] as String? ?? 'unknown',
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ipAddress: json['ip_address'] as String?,
    userAgent: json['user_agent'] as String?,
    details: json['details'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(json['details'] as Map<String, dynamic>)
        : const {},
  );
}

class SecurityEventPage {
  const SecurityEventPage({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<SecurityEvent> items;
  final int total;
  final int limit;
  final int offset;

  bool get hasMore => offset + items.length < total;

  factory SecurityEventPage.fromJson(Map<String, dynamic> json) =>
      SecurityEventPage(
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SecurityEvent.fromJson)
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
        offset: (json['offset'] as num?)?.toInt() ?? 0,
      );
}
