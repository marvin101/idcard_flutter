class Student {
  // ==========================================================
  // Personal Information
  // ==========================================================

  String fullName;
  String fatherName;
  String motherName;

  DateTime? dob;

  String gender;
  String bloodGroup;

  // ==========================================================
  // Academic Information
  // ==========================================================

  String admissionNo;
  String rollNo;

  String className;
  String section;
  String stream;
  String house;

  String session;

  // ==========================================================
  // Contact Information
  // ==========================================================

  String mobile;
  String aadhaar;
  String address;

  // ==========================================================
  // Photo
  // ==========================================================

  String? photoPath;

  Student({
    this.fullName = "",
    this.fatherName = "",
    this.motherName = "",
    this.dob,

    this.gender = "",
    this.bloodGroup = "",

    this.admissionNo = "",
    this.rollNo = "",

    this.className = "",
    this.section = "",
    this.stream = "",
    this.house = "",
    this.session = "",

    this.mobile = "",
    this.aadhaar = "",
    this.address = "",

    this.photoPath,
  });
}
