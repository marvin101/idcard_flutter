import 'student_field.dart';

class ApiStudent {
  final String uuid;

  final String sessionUuid;
  final String classUuid;
  final String sectionUuid;

  final String admissionNo;
  final String? rollNo;
  final String? stream;

  final String fullName;
  final String? fatherName;
  final String? motherName;

  final DateTime? dob;
  final String? gender;
  final String? bloodGroup;

  final String? mobile;
  final String? aadhaar;
  final String? address;
  final String? photoPath;

  final bool isActive;
  final List<StudentCustomFieldValue> customFields;
  final String verificationStatus;
  final String lifecycleStatus;
  final String? correctionNote;
  final DateTime? verifiedAt;
  final String? verifiedByUserUuid;
  final String? verifiedByName;
  final DateTime? printedAt;
  final String? printedByUserUuid;
  final String? printedByName;
  final int printCount;

  const ApiStudent({
    required this.uuid,
    required this.sessionUuid,
    required this.classUuid,
    required this.sectionUuid,
    required this.admissionNo,
    this.rollNo,
    this.stream,
    required this.fullName,
    this.fatherName,
    this.motherName,
    this.dob,
    this.gender,
    this.bloodGroup,
    this.mobile,
    this.aadhaar,
    this.address,
    this.photoPath,
    required this.isActive,
    this.customFields = const [],
    this.verificationStatus = 'pending',
    this.lifecycleStatus = 'pending',
    this.correctionNote,
    this.verifiedAt,
    this.verifiedByUserUuid,
    this.verifiedByName,
    this.printedAt,
    this.printedByUserUuid,
    this.printedByName,
    this.printCount = 0,
  });

  bool get isVerified => verificationStatus == 'verified';
  bool get isPrinted => printCount > 0;

  factory ApiStudent.fromJson(Map<String, dynamic> json) {
    return ApiStudent(
      uuid: json['uuid'] as String,
      sessionUuid: json['session_uuid'] as String,
      classUuid: json['class_uuid'] as String,
      sectionUuid: json['section_uuid'] as String,
      admissionNo: json['admission_no'] as String,
      rollNo: json['roll_no'] as String?,
      stream: json['stream'] as String?,
      fullName: json['full_name'] as String,
      fatherName: json['father_name'] as String?,
      motherName: json['mother_name'] as String?,
      dob: json['dob'] == null
          ? null
          : DateTime.tryParse(json['dob'] as String),
      gender: json['gender'] as String?,
      bloodGroup: json['blood_group'] as String?,
      mobile: json['mobile'] as String?,
      aadhaar: json['aadhaar'] as String?,
      address: json['address'] as String?,
      photoPath: json['photo_path'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      verificationStatus: json['verification_status'] as String? ?? 'pending',
      lifecycleStatus:
          json['lifecycle_status'] as String? ??
          ((json['print_count'] as num? ?? 0) > 0
              ? 'printed'
              : json['verification_status'] as String? ?? 'pending'),
      correctionNote: json['correction_note'] as String?,
      verifiedAt: _dateTime(json['verified_at']),
      verifiedByUserUuid: json['verified_by_user_uuid'] as String?,
      verifiedByName: json['verified_by_name'] as String?,
      printedAt: _dateTime(json['printed_at']),
      printedByUserUuid: json['printed_by_user_uuid'] as String?,
      printedByName: json['printed_by_name'] as String?,
      printCount: (json['print_count'] as num?)?.toInt() ?? 0,
      customFields: (json['custom_fields'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                StudentCustomFieldValue.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  static DateTime? _dateTime(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class StudentAuditEvent {
  const StudentAuditEvent({
    required this.uuid,
    required this.eventType,
    this.fieldName,
    this.oldValue,
    this.newValue,
    this.note,
    this.actorUserUuid,
    this.actorName,
    required this.createdAt,
  });

  final String uuid;
  final String eventType;
  final String? fieldName;
  final dynamic oldValue;
  final dynamic newValue;
  final String? note;
  final String? actorUserUuid;
  final String? actorName;
  final DateTime createdAt;

  factory StudentAuditEvent.fromJson(Map<String, dynamic> json) =>
      StudentAuditEvent(
        uuid: json['uuid'] as String,
        eventType: json['event_type'] as String,
        fieldName: json['field_name'] as String?,
        oldValue: json['old_value'],
        newValue: json['new_value'],
        note: json['note'] as String?,
        actorUserUuid: json['actor_user_uuid'] as String?,
        actorName: json['actor_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
