import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_models.dart';
import '../models/school_profile.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiService? api}) : _api = api ?? ApiService() {
    _api.setTokensRefreshedCallback(
      (access, refresh) async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(accessTokenPreferenceKey, access);
        await prefs.setString(refreshTokenPreferenceKey, refresh);
      },
      onRefreshed: () {
        if (_user != null) unawaited(refreshAuthority());
      },
    );
    _api.setSessionInvalidatedCallback(() {
      unawaited(invalidateSession());
    });
  }

  static const sessionExpiredMessage =
      'Your session has expired. Please sign in again.';
  static const accessTokenPreferenceKey = 'access_token';
  static const refreshTokenPreferenceKey = 'refresh_token';
  static const trustedDeviceTokenPreferenceKey = 'trusted_device_token';
  bool _rememberDevice = false;
  bool get rememberDevice => _rememberDevice;
  static const selectedSchoolPreferenceKey = 'selected_school_uuid';
  static const lastSelectedSchoolPreferenceKey = 'last_selected_school_uuid';

  final ApiService _api;

  AuthUser? _user;
  List<SchoolSummary> _schools = const [];
  List<SchoolAccess> _accesses = const [];
  SchoolSummary? _selectedSchool;
  int _authEpoch = 0;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String? _sessionMessage;
  String? _mfaChallengeToken;
  Future<void>? _sessionInvalidationFuture;

  AuthUser? get user => _user;
  List<SchoolSummary> get schools => _schools;
  List<SchoolAccess> get accesses => _accesses;
  SchoolSummary? get selectedSchool => _selectedSchool;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;
  String? get sessionMessage => _sessionMessage;
  bool get mfaRequired => _mfaChallengeToken != null;
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
  bool get canDeletePersonnel => canManageUsers;
  bool get canDesignCards => canManageUsers;
  List<SchoolSummary> get designableSchools {
    if (isPlatformAdmin) {
      return _schools.where((school) => school.isActive).toList();
    }
    final permitted = _accesses
        .where((access) => access.isSchoolAdministrator)
        .map((access) => access.schoolUuid)
        .toSet();
    return _schools
        .where((school) => school.isActive && permitted.contains(school.uuid))
        .toList();
  }

  bool get canPrintCards => canManageCardData;
  LifecyclePermissions get _lifecyclePermissions => lifecyclePermissionsFor(
    isPlatformAdmin: isPlatformAdmin,
    schoolRole: selectedSchoolAccess?.role,
  );
  bool get canVerifyStudents => _lifecyclePermissions.canVerify;
  bool get canViewStudentHistory => _lifecyclePermissions.canViewHistory;
  bool get canMarkStudentsPrinted => _lifecyclePermissions.canMarkPrinted;
  bool get canVerifyPersonnel => _lifecyclePermissions.canVerify;
  bool get canViewPersonnelHistory => _lifecyclePermissions.canViewHistory;
  bool get canMarkPersonnelPrinted => _lifecyclePermissions.canMarkPrinted;

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
      final token = prefs.getString(accessTokenPreferenceKey);
      if (token == null || token.isEmpty) {
        _loading = false;
        notifyListeners();
        return;
      }

      _api.setToken(token);
      _api.setRefreshToken(prefs.getString(refreshTokenPreferenceKey));
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

  Future<void> login(String username, String password, {bool rememberDevice = false}) async {
    _authEpoch++;
    _setBusy(true);
    _error = null;
    _sessionMessage = null;
    _mfaChallengeToken = null;
    _rememberDevice = rememberDevice;
    _sessionInvalidationFuture = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await _api.login(username.trim(), password, rememberDevice: rememberDevice, trustedDeviceToken: prefs.getString(trustedDeviceTokenPreferenceKey));
      if (result['mfa_required'] == true) {
        final challenge = result['challenge_token'] as String?;
        if (challenge == null || challenge.isEmpty) {
          throw const ApiException(500, 'Login response did not contain an MFA challenge.');
        }
        _mfaChallengeToken = challenge;
        _error = null;
        return;
      }
      final token = result['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException(
          500,
          'Login response did not contain an access token.',
        );
      }
      _mfaChallengeToken = null;
      final refresh = result['refresh_token'] as String?;
      final issuedTrustedToken = result['trusted_device_token'] as String?;
      if (issuedTrustedToken != null && issuedTrustedToken.isNotEmpty) {
        await prefs.setString(trustedDeviceTokenPreferenceKey, issuedTrustedToken);
      }
      _api.setToken(token);
      _api.setRefreshToken(refresh);
      if (refresh != null) {
        await prefs.setString(refreshTokenPreferenceKey, refresh);
      } else {
        await prefs.remove(refreshTokenPreferenceKey);
      }
      await prefs.setString(accessTokenPreferenceKey, token);
      await _loadCurrentUser();
    } on ApiException catch (e) {
      _error = e.message;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> verifyMfaLogin(String code) async {
    final challenge = _mfaChallengeToken;
    if (challenge == null) {
      throw const ApiException(400, 'There is no pending MFA sign-in.');
    }
    _setBusy(true);
    _error = null;
    try {
      final result = await _api.verifyMfaLogin(
        challengeToken: challenge,
        code: code,
        deviceName: kIsWeb ? 'Trusted browser' : 'Trusted device',
      );
      final token = result['access_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const ApiException(500, 'MFA verification did not return an access token.');
      }
      final refresh = result['refresh_token'] as String?;
      final prefs = await SharedPreferences.getInstance();
      final issuedTrustedToken = result['trusted_device_token'] as String?;
      if (issuedTrustedToken != null && issuedTrustedToken.isNotEmpty) {
        await prefs.setString(trustedDeviceTokenPreferenceKey, issuedTrustedToken);
      }
      _mfaChallengeToken = null;
      _api.setToken(token);
      _api.setRefreshToken(refresh);
      await prefs.setString(accessTokenPreferenceKey, token);
      if (refresh != null && refresh.isNotEmpty) {
        await prefs.setString(refreshTokenPreferenceKey, refresh);
      } else {
        await prefs.remove(refreshTokenPreferenceKey);
      }
      await _loadCurrentUser();
    } on ApiException catch (error) {
      _error = error.message;
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  void cancelMfaLogin() {
    _mfaChallengeToken = null;
    _error = null;
    notifyListeners();
  }

  bool _refreshingAuthority = false;
  Future<void> refreshAuthority() async {
    if (_refreshingAuthority || _user == null) return;
    _refreshingAuthority = true;
    try {
      await _loadCurrentUser();
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) await invalidateSession();
    } catch (_) {
      /* Keep local state during transient network failures. */
    } finally {
      _refreshingAuthority = false;
    }
  }

  Future<void> _loadCurrentUser() async {
    final epoch = _authEpoch;
    final userJson = await _api.getMe();
    if (epoch != _authEpoch) return;
    final user = AuthUser.fromJson(userJson);

    late final List<dynamic> schoolJson;
    late final List<dynamic> accessJson;
    if (user.isPlatformAdministrator) {
      schoolJson = await _api.getSchools();
      accessJson = const [];
    } else {
      final results = await Future.wait<List<dynamic>>([
        _api.getSchools(),
        _api.getUserSchools(user.uuid),
      ]);
      schoolJson = results[0];
      accessJson = results[1];
    }

    if (epoch != _authEpoch) return;
    _user = user;
    _schools = schoolJson
        .whereType<Map<String, dynamic>>()
        .map(SchoolSummary.fromJson)
        .toList();

    if (user.isPlatformAdministrator) {
      _accesses = const [];
    } else {
      _accesses = accessJson
          .whereType<Map<String, dynamic>>()
          .map(SchoolAccess.fromJson)
          .toList();
    }

    await _restoreSchoolSelection(epoch: epoch);
    if (epoch != _authEpoch) return;
    notifyListeners();
  }

  Future<void> _restoreSchoolSelection({int? epoch}) async {
    final prefs = await SharedPreferences.getInstance();
    if (epoch != null && epoch != _authEpoch) return;
    final activeSaved = prefs.getString(selectedSchoolPreferenceKey);
    final lastSaved = prefs.getString(lastSelectedSchoolPreferenceKey);
    final saved = activeSaved ?? lastSaved;

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
    if (candidate == null) {
      await prefs.remove(selectedSchoolPreferenceKey);
      if (saved != null) {
        await prefs.remove(lastSelectedSchoolPreferenceKey);
      }
    } else {
      await prefs.setString(selectedSchoolPreferenceKey, candidate.uuid);
      await prefs.setString(lastSelectedSchoolPreferenceKey, candidate.uuid);
    }
  }

  Future<void> selectSchool(SchoolSummary school) async {
    if (!isPlatformAdmin &&
        !_accesses.any((access) => access.schoolUuid == school.uuid)) {
      throw const ApiException(403, 'You do not have access to this school.');
    }
    _selectedSchool = school;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedSchoolPreferenceKey, school.uuid);
    await prefs.setString(lastSelectedSchoolPreferenceKey, school.uuid);
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

  Future<AuthUser> updateSelfProfile({
    required String username,
    required String fullName,
    String? email,
    String? mobile,
  }) async {
    final updated = AuthUser.fromJson(
      await _api.updateMe(
        username: username,
        fullName: fullName,
        email: email,
        mobile: mobile,
      ),
    );
    _user = updated;
    notifyListeners();
    return updated;
  }

  Future<AuthUser> uploadProfilePhoto(XFile photo) async {
    final updated = AuthUser.fromJson(await _api.uploadProfilePhoto(photo));
    _user = updated;
    notifyListeners();
    return updated;
  }

  Future<AuthUser> removeProfilePhoto() async {
    final updated = AuthUser.fromJson(await _api.removeProfilePhoto());
    _user = updated;
    notifyListeners();
    return updated;
  }

  Future<void> logout({bool notify = true}) async {
    _sessionMessage = null;
    _mfaChallengeToken = null;
    _sessionInvalidationFuture = null;
    final revocation = _api.revokeSession();
    await _clearSession(notify: notify);
    final logoutEpoch = _authEpoch;
    await revocation;
    if (logoutEpoch == _authEpoch) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(accessTokenPreferenceKey);
      await prefs.remove(refreshTokenPreferenceKey);
    }
  }

  Future<void> invalidateSession({bool notify = true}) {
    return _sessionInvalidationFuture ??= _clearSession(
      notify: notify,
      message: sessionExpiredMessage,
    );
  }

  Future<void> _clearSession({bool notify = true, String? message}) async {
    _authEpoch++;
    final lastSelectedSchoolUuid = _selectedSchool?.uuid;
    _api.setToken(null);
    _user = null;
    _mfaChallengeToken = null;
    _schools = const [];
    _accesses = const [];
    _selectedSchool = null;
    _sessionMessage = message;
    final prefs = await SharedPreferences.getInstance();
    if (lastSelectedSchoolUuid != null) {
      await prefs.setString(
        lastSelectedSchoolPreferenceKey,
        lastSelectedSchoolUuid,
      );
    }
    await prefs.remove(accessTokenPreferenceKey);
    await prefs.remove(refreshTokenPreferenceKey);
    await prefs.remove(selectedSchoolPreferenceKey);
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
