import 'dart:io';

import 'package:flutter/material.dart';

import '../models/student.dart';
import '../repositories/student_repository.dart';

class StudentFormProvider extends ChangeNotifier {
  // ==========================================================
  // DEPENDENCIES
  // ==========================================================

  final StudentRepository repository;

  // ==========================================================
  // CURRENT STUDENT
  // ==========================================================

  final Student currentStudent = Student();

  // ==========================================================
  // CONSTRUCTOR
  // ==========================================================

  StudentFormProvider({required this.repository}) {
    _initializePersonalControllers();
    _initializeAcademicControllers();
    _initializeContactControllers();
  }

  // ==========================================================
  // FORM KEY
  // ==========================================================

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // ==========================================================
  // PERSONAL INFORMATION CONTROLLERS
  // ==========================================================

  final TextEditingController fullNameController = TextEditingController();

  final TextEditingController fatherNameController = TextEditingController();

  final TextEditingController motherNameController = TextEditingController();

  final TextEditingController dobDayController = TextEditingController();

  final TextEditingController dobMonthController = TextEditingController();

  final TextEditingController dobYearController = TextEditingController();

  // ==========================================================
  // ACADEMIC INFORMATION CONTROLLERS
  // ==========================================================

  final TextEditingController admissionNoController = TextEditingController();

  final TextEditingController rollNoController = TextEditingController();

  final TextEditingController sessionController = TextEditingController();

  // ==========================================================
  // CONTACT INFORMATION CONTROLLERS
  // ==========================================================

  final TextEditingController mobileController = TextEditingController();

  final TextEditingController aadhaarController = TextEditingController();

  final TextEditingController addressController = TextEditingController();

  // ==========================================================
  // UI STATE
  // ==========================================================

  File? selectedPhoto;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  bool _isSaving = false;

  bool get isSaving => _isSaving;

  bool _isEditMode = false;

  bool get isEditMode => _isEditMode;

  // ==========================================================
  // PRIVATE INITIALIZATION
  // ==========================================================

  void _initializePersonalControllers() {
    fullNameController.addListener(() {
      currentStudent.fullName = fullNameController.text.trim();
    });

    fatherNameController.addListener(() {
      currentStudent.fatherName = fatherNameController.text.trim();
    });

    motherNameController.addListener(() {
      currentStudent.motherName = motherNameController.text.trim();
    });

    dobDayController.addListener(_updateDob);
    dobMonthController.addListener(_updateDob);
    dobYearController.addListener(_updateDob);
  }

  void _initializeAcademicControllers() {
    admissionNoController.addListener(() {
      currentStudent.admissionNo = admissionNoController.text.trim();
    });

    rollNoController.addListener(() {
      currentStudent.rollNo = rollNoController.text.trim();
    });

    sessionController.addListener(() {
      currentStudent.session = sessionController.text.trim();
    });
  }

  void _initializeContactControllers() {
    mobileController.addListener(() {
      currentStudent.mobile = mobileController.text.trim();
    });

    aadhaarController.addListener(() {
      currentStudent.aadhaar = aadhaarController.text.trim();
    });

    addressController.addListener(() {
      currentStudent.address = addressController.text.trim();
    });
  }

  void _updateDob() {
    final day = int.tryParse(dobDayController.text);
    final month = int.tryParse(dobMonthController.text);
    final year = int.tryParse(dobYearController.text);

    if (day == null || month == null || year == null) {
      currentStudent.dob = null;
      return;
    }

    try {
      currentStudent.dob = DateTime(year, month, day);
    } catch (_) {
      currentStudent.dob = null;
    }
  }
  // ==========================================================
  // DROPDOWN GETTERS
  // ==========================================================

  String? get selectedClass =>
      currentStudent.className.isEmpty ? null : currentStudent.className;

  String? get selectedSection =>
      currentStudent.section.isEmpty ? null : currentStudent.section;

  String? get selectedStream =>
      currentStudent.stream.isEmpty ? null : currentStudent.stream;

  String? get selectedHouse =>
      currentStudent.house.isEmpty ? null : currentStudent.house;

  String? get selectedGender =>
      currentStudent.gender.isEmpty ? null : currentStudent.gender;

  String? get selectedBloodGroup =>
      currentStudent.bloodGroup.isEmpty ? null : currentStudent.bloodGroup;

  // ==========================================================
  // DROPDOWN SETTERS
  // ==========================================================

  void setClass(String? value) {
    currentStudent.className = value ?? "";
    notifyListeners();
  }

  void setSection(String? value) {
    currentStudent.section = value ?? "";
    notifyListeners();
  }

  void setStream(String? value) {
    currentStudent.stream = value ?? "";
    notifyListeners();
  }

  void setHouse(String? value) {
    currentStudent.house = value ?? "";
    notifyListeners();
  }

  void setGender(String? value) {
    currentStudent.gender = value ?? "";
    notifyListeners();
  }

  void setBloodGroup(String? value) {
    currentStudent.bloodGroup = value ?? "";
    notifyListeners();
  }

  // ==========================================================
  // PHOTO
  // ==========================================================

  void setPhoto(File photo) {
    selectedPhoto = photo;
    currentStudent.photoPath = photo.path;
    notifyListeners();
  }

  void removePhoto() {
    selectedPhoto = null;
    currentStudent.photoPath = null;
    notifyListeners();
  }

  // ==========================================================
  // FORM VALIDATION
  // ==========================================================

  bool validate() {
    return formKey.currentState?.validate() ?? false;
  }

  // ==========================================================
  // RESET FORM
  // ==========================================================

  void clearForm() {
    // Personal
    fullNameController.clear();
    fatherNameController.clear();
    motherNameController.clear();

    dobDayController.clear();
    dobMonthController.clear();
    dobYearController.clear();

    // Academic
    admissionNoController.clear();
    rollNoController.clear();
    sessionController.clear();

    // Contact
    mobileController.clear();
    aadhaarController.clear();
    addressController.clear();

    // Student Model
    currentStudent
      ..fullName = ""
      ..fatherName = ""
      ..motherName = ""
      ..dob = null
      ..gender = ""
      ..bloodGroup = ""
      ..admissionNo = ""
      ..rollNo = ""
      ..className = ""
      ..section = ""
      ..stream = ""
      ..house = ""
      ..session = ""
      ..mobile = ""
      ..aadhaar = ""
      ..address = ""
      ..photoPath = null;

    selectedPhoto = null;

    notifyListeners();
  }

  // ==========================================================
  // LOAD STUDENT INTO FORM
  // ==========================================================

  void populateForm(Student student) {
    fullNameController.text = student.fullName;
    fatherNameController.text = student.fatherName;
    motherNameController.text = student.motherName;

    if (student.dob != null) {
      dobDayController.text = student.dob!.day.toString().padLeft(2, '0');

      dobMonthController.text = student.dob!.month.toString().padLeft(2, '0');

      dobYearController.text = student.dob!.year.toString();
    }

    admissionNoController.text = student.admissionNo;
    rollNoController.text = student.rollNo;
    sessionController.text = student.session;

    mobileController.text = student.mobile;
    aadhaarController.text = student.aadhaar;
    addressController.text = student.address;

    currentStudent
      ..fullName = student.fullName
      ..fatherName = student.fatherName
      ..motherName = student.motherName
      ..dob = student.dob
      ..gender = student.gender
      ..bloodGroup = student.bloodGroup
      ..admissionNo = student.admissionNo
      ..rollNo = student.rollNo
      ..className = student.className
      ..section = student.section
      ..stream = student.stream
      ..house = student.house
      ..session = student.session
      ..mobile = student.mobile
      ..aadhaar = student.aadhaar
      ..address = student.address
      ..photoPath = student.photoPath;

    if (student.photoPath != null && student.photoPath!.isNotEmpty) {
      selectedPhoto = File(student.photoPath!);
    }

    notifyListeners();
  }
  // ==========================================================
  // LOADING / SAVING STATE
  // ==========================================================

  void setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void setSaving(bool value) {
    if (_isSaving == value) return;
    _isSaving = value;
    notifyListeners();
  }

  void setEditMode(bool value) {
    if (_isEditMode == value) return;
    _isEditMode = value;
    notifyListeners();
  }

  // ==========================================================
  // SAVE STUDENT
  // ==========================================================

  Future<int?> saveStudent() async {
    if (!validate()) return null;

    setSaving(true);

    try {
      final id = await repository.addStudent(currentStudent);
      return id;
    } finally {
      setSaving(false);
    }
  }

  // ==========================================================
  // UPDATE STUDENT
  // ==========================================================

  Future<void> updateStudent() async {
    if (!validate()) return;

    setSaving(true);

    try {
      await repository.updateStudent(currentStudent);
    } finally {
      setSaving(false);
    }
  }

  // ==========================================================
  // LOAD STUDENT
  // ==========================================================

  Future<bool> loadStudent(int id) async {
    setLoading(true);

    try {
      final student = await repository.getStudentById(id);

      if (student == null) {
        return false;
      }

      populateForm(student);
      setEditMode(true);

      return true;
    } finally {
      setLoading(false);
    }
  }

  // ==========================================================
  // DELETE STUDENT
  // ==========================================================

  Future<void> deleteStudent(int id) async {
    setLoading(true);

    try {
      await repository.deleteStudent(id);
    } finally {
      setLoading(false);
    }
  }

  // ==========================================================
  // CREATE NEW FORM
  // ==========================================================

  void createNewStudent() {
    clearForm();
    setEditMode(false);
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    // Personal
    fullNameController.dispose();
    fatherNameController.dispose();
    motherNameController.dispose();

    dobDayController.dispose();
    dobMonthController.dispose();
    dobYearController.dispose();

    // Academic
    admissionNoController.dispose();
    rollNoController.dispose();
    sessionController.dispose();

    // Contact
    mobileController.dispose();
    aadhaarController.dispose();
    addressController.dispose();

    super.dispose();
  }
}
