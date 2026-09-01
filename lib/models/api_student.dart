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

  bool get containsSensitiveField {
    final parts = (fieldName ?? '')
        .replaceAll('[', '.')
        .replaceAll(']', '')
        .split('.')
        .map((part) => part.toLowerCase().replaceAll('-', '_'));
    return parts.any(
      (part) =>
          part == 'password' ||
          part == 'password_hash' ||
          part == 'token' ||
          part == 'secret' ||
          part.contains('password') ||
          part.contains('secret') ||
          part.endsWith('_token'),
    );
  }

  String get friendlyEventLabel => switch (eventType) {
    'student_created' => 'Student Created',
    'student_field_updated' => 'Student Details Updated',
    'student_photo_added' => 'Photo Added',
    'student_photo_replaced' => 'Photo Replaced',
    'student_photo_removed' => 'Photo Removed',
    'verification_status_changed' => 'Verification Status Changed',
    'correction_note_changed' => 'Correction Note Changed',
    'marked_printed' => 'Card Marked Printed',
    'reprinted' => 'Card Reprint Recorded',
    'student_deactivated' => 'Student Deactivated',
    _ => _words(eventType),
  };

  String? get friendlyFieldLabel {
    final field = fieldName;
    if (field == null || field.isEmpty || containsSensitiveField) return null;
    const labels = {
      'verification_status': 'Verification status',
      'correction_note': 'Correction note',
      'print_count': 'Print count',
      'full_name': 'Student name',
      'admission_no': 'Admission number',
      'roll_no': 'Roll number',
      'father_name': "Father's name",
      'mother_name': "Mother's name",
      'blood_group': 'Blood group',
      'session_id': 'Academic session',
      'class_id': 'Class',
      'section_id': 'Section',
      'is_active': 'Active status',
      'photo_path': 'Photo',
    };
    if (labels.containsKey(field)) return labels[field];
    if (field.startsWith('custom_fields.')) {
      return 'Custom field: ${_words(field.substring('custom_fields.'.length))}';
    }
    return _words(field);
  }

  String get friendlySummary {
    if (containsSensitiveField) return 'Sensitive change hidden';
    final label = friendlyFieldLabel;
    if (label != null) {
      return '$label: ${_displayValue(oldValue)} → ${_displayValue(newValue)}';
    }
    return switch (eventType) {
      'student_created' => 'Student record created',
      'student_photo_added' => 'A student photo was added',
      'student_photo_replaced' => 'The student photo was replaced',
      'student_photo_removed' => 'The student photo was removed',
      'student_deactivated' => 'The student record was deactivated',
      _ => 'Student record event',
    };
  }

  static String _displayValue(dynamic value) {
    if (value == null || value == '') return 'Not set';
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) return value.map(_displayValue).join(', ');
    if (value is Map) {
      return value.entries
          .map(
            (entry) =>
                '${_words('${entry.key}')}: ${_displayValue(entry.value)}',
          )
          .join(', ');
    }
    final text = '$value';
    return switch (text) {
      'pending' => 'Pending',
      'needs_correction' => 'Needs Correction',
      'verified' => 'Verified',
      _ => text,
    };
  }

  static String _words(String value) => value
      .replaceAll('.', ' ')
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class StudentLifecycleSelection {
  const StudentLifecycleSelection({
    required this.selectedCount,
    required this.verifyIneligibleCount,
    required this.printIneligibleCount,
    required this.reprintCount,
  });

  final int selectedCount;
  final int verifyIneligibleCount;
  final int printIneligibleCount;
  final int reprintCount;

  bool get canBatchVerify => selectedCount > 0 && verifyIneligibleCount == 0;
  bool get canBatchMarkPrinted =>
      selectedCount > 0 && printIneligibleCount == 0;

  factory StudentLifecycleSelection.from(
    Iterable<ApiStudent> students,
    Set<String> selectedUuids,
  ) {
    final selected = students
        .where((student) => selectedUuids.contains(student.uuid))
        .toList();
    return StudentLifecycleSelection(
      selectedCount: selected.length,
      verifyIneligibleCount: selected
          .where(
            (student) =>
                student.verificationStatus != 'pending' &&
                student.verificationStatus != 'needs_correction',
          )
          .length,
      printIneligibleCount: selected
          .where((student) => !student.isVerified)
          .length,
      reprintCount: selected.where((student) => student.isPrinted).length,
    );
  }
}
