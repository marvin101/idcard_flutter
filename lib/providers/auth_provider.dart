import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';
import '../models/school_profile.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiService? api}) : _api = api ?? ApiService() {
    _api.setSessionInvalidatedCallback(() {
      unawaited(invalidateSession());
    });
  }

  static const sessionExpiredMessage =
      'Your session has expired. Please sign in again.';

  final ApiService _api;

  AuthUser? _user;
  List<SchoolSummary> _schools = const [];
  List<SchoolAccess> _accesses = const [];
  SchoolSummary? _selectedSchool;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _sessionMessage;
  Future<void>? _sessionInvalidationFuture;

  AuthUser? get user => _user;
  List<SchoolSummary> get schools => _schools;
  List<SchoolAccess> get accesses => _accesses;
  SchoolSummary? get selectedSchool => _selectedSchool;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;
  String? get sessionMessage => _sessionMessage;
  bool get isAuthenticated => _user != null;
  bool get isPlatformAdmin => _user?.isPlatformAdministrator ?? false;

  bool get canManageUsers {
    if (isPlatformAdmin) return true;
    return selectedSchoolAccess?.isSchoolAdministrator ?? false;
  }

  bool get canManageAcademicSessions => canManageUsers;
  bool get canManageClasses => canManageUsers;
  bool get canManageSchoolProfile => canManageUsers;
  bool get canManageCardData {
    if (canManageUsers) return true;
    return selectedSchoolAccess?.isCardOperator ?? false;
  }

  bool get canDeleteStudents => canManageUsers;
  bool get canDesignCards => canManageUsers;
  bool get canPrintCards => canManageUsers;

  SchoolAccess? get selectedSchoolAccess {
    final id = _selectedSchool?.uuid;
    if (id == null) return null;
    for (final access in _accesses) {
      if (access.schoolUuid == id) return access;
    }
    return null;
  }

  Future<void> initialize() async {
    _loading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      if (token == null || token.isEmpty) {
        _loading = false;
        notifyListeners();
        return;
      }

      _api.setToken(token);
      await _loadCurrentUser();
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await invalidateSession(notify: false);
      } else {
        await logout(notify: false);
      }
    } catch (_) {
      await logout(notify: false);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    _setBusy(true);
    _error = null;
    _sessionMessage = null;
    _sessionInvalidationFuture = null;
    try {
      final result = await _api.login(username.trim(), password);
      final token = result['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          500,
          'Login response did not contain an access token.',
        );
      }

      _api.setToken(token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
      await _loadCurrentUser();
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _loadCurrentUser() async {
    final userJson = await _api.getMe();
    _user = AuthUser.fromJson(userJson);

    final schoolJson = await _api.getSchools();
    _schools = schoolJson
        .whereType<Map<String, dynamic>>()
        .map(SchoolSummary.fromJson)
        .toList();

    if (_user!.isPlatformAdministrator) {
      _accesses = const [];
    } else {
      final accessJson = await _api.getUserSchools(_user!.uuid);
      _accesses = accessJson
          .whereType<Map<String, dynamic>>()
          .map(SchoolAccess.fromJson)
          .toList();
    }

    await _restoreSchoolSelection();
    notifyListeners();
  }

  Future<void> _restoreSchoolSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selected_school_uuid');

    SchoolSummary? candidate;
    if (saved != null) {
      for (final school in _schools) {
        if (school.uuid == saved) {
          candidate = school;
          break;
        }
      }
    }

    if (candidate == null && _schools.length == 1) {
      candidate = _schools.first;
    }

    if (candidate != null &&
        (!isPlatformAdmin &&
            !_accesses.any((access) => access.schoolUuid == candidate!.uuid))) {
      candidate = null;
    }

    _selectedSchool = candidate;
  }

  Future<void> selectSchool(SchoolSummary school) async {
    if (!isPlatformAdmin &&
        !_accesses.any((access) => access.schoolUuid == school.uuid)) {
      throw const ApiException(403, 'You do not have access to this school.');
    }
    _selectedSchool = school;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_school_uuid', school.uuid);
    notifyListeners();
  }

  void applySchoolProfile(SchoolProfile profile) {
    final updated = SchoolSummary(
      uuid: profile.uuid,
      code: profile.schoolCode,
      name: profile.schoolName,
      isActive: profile.isActive,
    );
    _schools = [
      for (final school in _schools)
        if (school.uuid == profile.uuid) updated else school,
    ];
    if (_selectedSchool?.uuid == profile.uuid) {
      _selectedSchool = updated;
    }
    notifyListeners();
  }

  Future<void> logout({bool notify = true}) async {
    _sessionMessage = null;
    _sessionInvalidationFuture = null;
    await _clearSession(notify: notify);
  }

  Future<void> invalidateSession({bool notify = true}) {
    return _sessionInvalidationFuture ??= _clearSession(
      notify: notify,
      message: sessionExpiredMessage,
    );
  }

  Future<void> _clearSession({bool notify = true, String? message}) async {
    _api.setToken(null);
    _user = null;
    _schools = const [];
    _accesses = const [];
    _selectedSchool = null;
    _sessionMessage = message;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('selected_school_uuid');
    if (notify) notifyListeners();
  }

  ApiService get api => _api;

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }
}
