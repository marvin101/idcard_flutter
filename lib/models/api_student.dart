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
  });

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
    );
  }
}
