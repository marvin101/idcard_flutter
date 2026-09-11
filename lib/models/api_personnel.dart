enum PersonnelType {
  teacher,
  staff;

  String get apiValue => name;
  String get label => this == PersonnelType.teacher ? 'Teacher' : 'Staff';
  String get pluralLabel =>
      this == PersonnelType.teacher ? 'Teachers' : 'Staff';
}

class ApiPersonnel {
  const ApiPersonnel({
    required this.uuid,
    required this.personnelType,
    required this.employeeNo,
    required this.fullName,
    required this.designation,
    required this.department,
    required this.dob,
    required this.gender,
    required this.bloodGroup,
    required this.mobile,
    required this.email,
    required this.address,
    required this.photoPath,
    required this.verificationStatus,
    required this.lifecycleStatus,
    required this.correctionNote,
    required this.verifiedAt,
    required this.verifiedByName,
    required this.printedAt,
    required this.printedByName,
    required this.printCount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uuid;
  final PersonnelType personnelType;
  final String employeeNo;
  final String fullName;
  final String? designation;
  final String? department;
  final DateTime? dob;
  final String? gender;
  final String? bloodGroup;
  final String? mobile;
  final String? email;
  final String? address;
  final String? photoPath;
  final String verificationStatus;
  final String lifecycleStatus;
  final String? correctionNote;
  final DateTime? verifiedAt;
  final String? verifiedByName;
  final DateTime? printedAt;
  final String? printedByName;
  final int printCount;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isVerified => verificationStatus == 'verified';
  bool get isPrinted => printCount > 0;

  factory ApiPersonnel.fromJson(Map<String, dynamic> json) => ApiPersonnel(
    uuid: json['uuid'] as String,
    personnelType: PersonnelType.values.byName(
      json['personnel_type'] as String,
    ),
    employeeNo: json['employee_no'] as String,
    fullName: json['full_name'] as String,
    designation: json['designation'] as String?,
    department: json['department'] as String?,
    dob: _date(json['dob']),
    gender: json['gender'] as String?,
    bloodGroup: json['blood_group'] as String?,
    mobile: json['mobile'] as String?,
    email: json['email'] as String?,
    address: json['address'] as String?,
    photoPath: json['photo_path'] as String?,
    verificationStatus: json['verification_status'] as String? ?? 'pending',
    lifecycleStatus: json['lifecycle_status'] as String? ?? 'pending',
    correctionNote: json['correction_note'] as String?,
    verifiedAt: _date(json['verified_at']),
    verifiedByName: json['verified_by_name'] as String?,
    printedAt: _date(json['printed_at']),
    printedByName: json['printed_by_name'] as String?,
    printCount: (json['print_count'] as num?)?.toInt() ?? 0,
    isActive: json['is_active'] as bool? ?? true,
    createdAt:
        _date(json['created_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt:
        _date(json['updated_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
  );

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class ApiPersonnelPage {
  const ApiPersonnelPage({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
    required this.hasMore,
  });

  final List<ApiPersonnel> items;
  final int total;
  final int offset;
  final int limit;
  final bool hasMore;

  factory ApiPersonnelPage.fromJson(Map<String, dynamic> json) =>
      ApiPersonnelPage(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) => ApiPersonnel.fromJson(item as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        offset: (json['offset'] as num?)?.toInt() ?? 0,
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        hasMore: json['has_more'] == true,
      );
}

class PersonnelAuditEvent {
  const PersonnelAuditEvent({
    required this.eventType,
    required this.fieldName,
    required this.oldValue,
    required this.newValue,
    required this.note,
    required this.actorName,
    required this.createdAt,
  });

  final String eventType;
  final String? fieldName;
  final Object? oldValue;
  final Object? newValue;
  final String? note;
  final String? actorName;
  final DateTime createdAt;

  String get label => switch (eventType) {
    'personnel_created' => 'Personnel Created',
    'personnel_deactivated' => 'Personnel Deactivated',
    'personnel_field_updated' => 'Personnel Updated',
    'verification_status_changed' => 'Verification Status Changed',
    'correction_note_changed' => 'Correction Note Changed',
    'marked_printed' => 'Marked Printed',
    'reprinted' => 'Card Reprinted',
    _ => eventType.replaceAll('_', ' '),
  };

  String get summary {
    if (fieldName != null) {
      return '$fieldName: ${oldValue ?? '—'} → ${newValue ?? '—'}';
    }
    return label;
  }

  factory PersonnelAuditEvent.fromJson(Map<String, dynamic> json) =>
      PersonnelAuditEvent(
        eventType: json['event_type'] as String,
        fieldName: json['field_name'] as String?,
        oldValue: json['old_value'],
        newValue: json['new_value'],
        note: json['note'] as String?,
        actorName: json['actor_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
