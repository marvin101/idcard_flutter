import 'package:flutter/material.dart';

import '../models/academic_session.dart';
import '../models/school_class.dart';
import '../models/section.dart';
import '../services/api_service.dart';

class ApiStudentFormProvider extends ChangeNotifier {
  ApiStudentFormProvider({required this.api, required this.schoolUuid}) {
    _loadAcademicData();
  }

  final ApiService api;
  final String schoolUuid;

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

      final currentSession = sessions.where((s) => s.isCurrent).isEmpty
          ? null
          : sessions.where((s) => s.isCurrent).first;

      selectedSessionUuid = currentSession?.uuid;

      if (selectedSessionUuid == null && sessions.isNotEmpty) {
        selectedSessionUuid = sessions.first.uuid;
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
  // Session
  // ----------------------------------------------------------

  void setSession(String? uuid) {
    selectedSessionUuid = uuid;
    notifyListeners();
  }

  // ----------------------------------------------------------
  // Class
  // ----------------------------------------------------------

  Future<void> setClass(String? uuid) async {
    selectedClassUuid = uuid;

    selectedSectionUuid = null;
    sections = const [];

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
      return DateTime(year, month, day);
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
  // Create student
  // ----------------------------------------------------------

  Future<bool> saveStudent() async {
    if (!validate()) return false;

    _saving = true;
    _error = null;
    notifyListeners();

    try {
      await api.createStudent(
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
