import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/academic_session.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../services/api_service.dart';
import '../models/api_student.dart';

class ApiStudentFormProvider extends ChangeNotifier {
  ApiStudentFormProvider({
    required this.api,
    required this.schoolUuid,
    this.student,
  }) {
    _loadAcademicData();
  }

  final ApiService api;
  final String schoolUuid;
  final ApiStudent? student;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // ----------------------------------------------------------
  // Controllers
  // ----------------------------------------------------------

  final fullNameController = TextEditingController();
  final fatherNameController = TextEditingController();
  final motherNameController = TextEditingController();

  final dobDayController = TextEditingController();
  final dobMonthController = TextEditingController();
  final dobYearController = TextEditingController();

  final admissionNoController = TextEditingController();
  final rollNoController = TextEditingController();
  final streamController = TextEditingController();

  final mobileController = TextEditingController();
  final aadhaarController = TextEditingController();
  final addressController = TextEditingController();

  // ----------------------------------------------------------
  // Lookup data
  // ----------------------------------------------------------

  List<AcademicSession> sessions = const [];
  List<SchoolClass> classes = const [];
  List<SchoolSection> sections = const [];

  String? selectedSessionUuid;
  String? selectedClassUuid;
  String? selectedSectionUuid;

  String? selectedGender;
  String? selectedBloodGroup;

  // ----------------------------------------------------------
  // Student photo
  // ----------------------------------------------------------

  XFile? _selectedPhoto;

  XFile? get selectedPhoto => _selectedPhoto;

  /// Existing photo already stored by the backend.
  ///
  /// The backend returns values such as:
  /// /media/students/`student-uuid`/photo.jpg
  String? get existingPhotoUrl {
    final path = student?.photoPath;

    if (path == null || path.trim().isEmpty) {
      return null;
    }

    final trimmed = path.trim();

    // Already a complete URL.
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    // Backend normally returns an absolute path beginning with /media/...
    if (trimmed.startsWith('/')) {
      return '${api.baseUrl}$trimmed';
    }

    return '${api.baseUrl}/$trimmed';
  }

  void setSelectedPhoto(XFile photo) {
    _selectedPhoto = photo;
    notifyListeners();
  }

  void clearSelectedPhoto() {
    _selectedPhoto = null;
    notifyListeners();
  }

  // ----------------------------------------------------------
  // State
  // ----------------------------------------------------------

  bool _loading = true;
  bool get loading => _loading;

  bool _loadingSections = false;
  bool get loadingSections => _loadingSections;

  bool _saving = false;
  bool get saving => _saving;

  String? _error;
  String? get error => _error;

  // ----------------------------------------------------------
  // Initial lookup loading
  // ----------------------------------------------------------

  Future<void> _loadAcademicData() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      sessions = await api.getAcademicSessions(schoolUuid);
      classes = await api.getClasses(schoolUuid);

      // --------------------------------------------------------
      // Edit mode
      // --------------------------------------------------------

      if (student != null) {
        _populateStudentFields(student!);

        // Existing academic session.
        if (sessions.any((s) => s.uuid == student!.sessionUuid)) {
          selectedSessionUuid = student!.sessionUuid;
        }

        // Existing class.
        if (classes.any((c) => c.uuid == student!.classUuid)) {
          selectedClassUuid = student!.classUuid;

          // Sections depend on the selected class.
          sections = await api.getSections(
            schoolUuid: schoolUuid,
            classUuid: student!.classUuid,
          );

          if (sections.any((s) => s.uuid == student!.sectionUuid)) {
            selectedSectionUuid = student!.sectionUuid;
          }
        }
      }
      // --------------------------------------------------------
      // Add mode
      // --------------------------------------------------------
      else {
        final currentSessions = sessions.where((s) => s.isCurrent).toList();

        if (currentSessions.isNotEmpty) {
          selectedSessionUuid = currentSessions.first.uuid;
        } else if (sessions.isNotEmpty) {
          selectedSessionUuid = sessions.first.uuid;
        }
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------
  // Student field population
  // ----------------------------------------------------------

  void _populateStudentFields(ApiStudent student) {
    fullNameController.text = student.fullName;

    fatherNameController.text = student.fatherName ?? '';
    motherNameController.text = student.motherName ?? '';

    admissionNoController.text = student.admissionNo;
    rollNoController.text = student.rollNo ?? '';
    streamController.text = student.stream ?? '';

    mobileController.text = student.mobile ?? '';
    aadhaarController.text = student.aadhaar ?? '';
    addressController.text = student.address ?? '';

    selectedGender = student.gender;
    selectedBloodGroup = student.bloodGroup;

    if (student.dob != null) {
      dobDayController.text = student.dob!.day.toString().padLeft(2, '0');

      dobMonthController.text = student.dob!.month.toString().padLeft(2, '0');

      dobYearController.text = student.dob!.year.toString();
    }
  }

  // ----------------------------------------------------------
  // Session
  // ----------------------------------------------------------

  void setSession(String? uuid) {
    selectedSessionUuid = uuid;

    // Cascading reset.
    selectedClassUuid = null;
    selectedSectionUuid = null;

    sections = const [];

    _error = null;

    notifyListeners();
  }

  // ----------------------------------------------------------
  // Class
  // ----------------------------------------------------------

  Future<void> setClass(String? uuid) async {
    selectedClassUuid = uuid;

    // Cascading reset.
    selectedSectionUuid = null;
    sections = const [];

    _error = null;

    notifyListeners();

    if (uuid == null || uuid.isEmpty) {
      return;
    }

    _loadingSections = true;
    notifyListeners();

    try {
      sections = await api.getSections(schoolUuid: schoolUuid, classUuid: uuid);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loadingSections = false;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------
  // Section
  // ----------------------------------------------------------

  void setSection(String? uuid) {
    selectedSectionUuid = uuid;
    notifyListeners();
  }

  // ----------------------------------------------------------
  // Other dropdowns
  // ----------------------------------------------------------

  void setGender(String? value) {
    selectedGender = value;
    notifyListeners();
  }

  void setBloodGroup(String? value) {
    selectedBloodGroup = value;
    notifyListeners();
  }

  // ----------------------------------------------------------
  // Date of birth
  // ----------------------------------------------------------

  DateTime? get dob {
    final day = int.tryParse(dobDayController.text);
    final month = int.tryParse(dobMonthController.text);
    final year = int.tryParse(dobYearController.text);

    if (day == null || month == null || year == null) {
      return null;
    }

    try {
      final date = DateTime(year, month, day);

      // Prevent DateTime from silently normalising invalid dates.
      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }

      return date;
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------------------------
  // Validation
  // ----------------------------------------------------------

  bool validate() {
    if (!(formKey.currentState?.validate() ?? false)) {
      return false;
    }

    if (selectedSessionUuid == null) {
      _error = 'Please select an academic session.';
      notifyListeners();
      return false;
    }

    if (selectedClassUuid == null) {
      _error = 'Please select a class.';
      notifyListeners();
      return false;
    }

    if (selectedSectionUuid == null) {
      _error = 'Please select a section.';
      notifyListeners();
      return false;
    }

    return true;
  }

  // ----------------------------------------------------------
  // Save student
  // ----------------------------------------------------------

  Future<bool> saveStudent() async {
    if (!validate()) {
      return false;
    }

    _saving = true;
    _error = null;
    notifyListeners();

    try {
      // ========================================================
      // ADD MODE
      // ========================================================

      if (student == null) {
        final createdStudent = await api.createStudent(
          schoolUuid: schoolUuid,
          sessionUuid: selectedSessionUuid!,
          classUuid: selectedClassUuid!,
          sectionUuid: selectedSectionUuid!,
          admissionNo: admissionNoController.text.trim(),
          rollNo: _nullable(rollNoController.text),
          stream: _nullable(streamController.text),
          fullName: fullNameController.text.trim(),
          fatherName: _nullable(fatherNameController.text),
          motherName: _nullable(motherNameController.text),
          dob: dob,
          gender: selectedGender,
          bloodGroup: selectedBloodGroup,
          mobile: _nullable(mobileController.text),
          aadhaar: _nullable(aadhaarController.text),
          address: _nullable(addressController.text),
        );

        // ------------------------------------------------------
        // Photo upload is deliberately separate from student
        // creation.
        //
        // We will upload _selectedPhoto using the newly created
        // student's UUID in the next step.
        // ------------------------------------------------------

        if (_selectedPhoto != null) {
          await api.uploadStudentPhoto(
            schoolUuid: schoolUuid,
            studentUuid: createdStudent.uuid,
            photo: _selectedPhoto!,
          );
        }
      }
      // ========================================================
      // EDIT MODE
      // ========================================================
      else {
        await api.updateStudent(
          schoolUuid: schoolUuid,
          studentUuid: student!.uuid,
          sessionUuid: selectedSessionUuid!,
          classUuid: selectedClassUuid!,
          sectionUuid: selectedSectionUuid!,
          admissionNo: admissionNoController.text.trim(),
          rollNo: _nullable(rollNoController.text),
          stream: _nullable(streamController.text),
          fullName: fullNameController.text.trim(),
          fatherName: _nullable(fatherNameController.text),
          motherName: _nullable(motherNameController.text),
          dob: dob,
          gender: selectedGender,
          bloodGroup: selectedBloodGroup,
          mobile: _nullable(mobileController.text),
          aadhaar: _nullable(aadhaarController.text),
          address: _nullable(addressController.text),
        );

        // ------------------------------------------------------
        // If a new photo was selected during editing, upload it
        // separately.
        // ------------------------------------------------------

        if (_selectedPhoto != null) {
          await api.uploadStudentPhoto(
            schoolUuid: schoolUuid,
            studentUuid: student!.uuid,
            photo: _selectedPhoto!,
          );
        }
      }

      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------
  // Helper
  // ----------------------------------------------------------

  String? _nullable(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  // ----------------------------------------------------------
  // Dispose
  // ----------------------------------------------------------

  @override
  void dispose() {
    fullNameController.dispose();
    fatherNameController.dispose();
    motherNameController.dispose();

    dobDayController.dispose();
    dobMonthController.dispose();
    dobYearController.dispose();

    admissionNoController.dispose();
    rollNoController.dispose();
    streamController.dispose();

    mobileController.dispose();
    aadhaarController.dispose();
    addressController.dispose();

    super.dispose();
  }
}
