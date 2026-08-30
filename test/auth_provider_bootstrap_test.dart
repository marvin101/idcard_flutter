import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BootstrapApi extends ApiService {
  _BootstrapApi({
    this.schoolsGate,
    this.accessGate,
    this.schoolsStarted,
    this.accessStarted,
    this.allowedSchoolUuids = const ['school-1', 'school-2'],
  });

  final Completer<void>? schoolsGate;
  final Completer<void>? accessGate;
  final Completer<void>? schoolsStarted;
  final Completer<void>? accessStarted;
  final List<String> allowedSchoolUuids;

  @override
  void setToken(String? token) {}

  @override
  Future<Map<String, dynamic>> getMe() async => {
    'uuid': 'user-1',
    'username': 'admin',
    'full_name': 'School Admin',
    'platform_role': null,
    'is_platform_admin': false,
    'is_active': true,
  };

  @override
  Future<List<dynamic>> getSchools() async {
    schoolsStarted?.complete();
    await schoolsGate?.future;
    return [_school('school-1'), _school('school-2')];
  }

  @override
  Future<List<dynamic>> getUserSchools(String userUuid) async {
    accessStarted?.complete();
    await accessGate?.future;
    return allowedSchoolUuids.map(_access).toList();
  }

  @override
  void dispose() {}
}

Map<String, dynamic> _school(String uuid) => {
  'uuid': uuid,
  'school_code': uuid.toUpperCase(),
  'school_name': 'School $uuid',
  'is_active': true,
};

Map<String, dynamic> _access(String uuid) => {
  'school_uuid': uuid,
  'school_name': 'School $uuid',
  'role': 'school_admin',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('valid last-school preference is restored and activated', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token',
      'last_selected_school_uuid': 'school-2',
    });
    final provider = AuthProvider(api: _BootstrapApi());

    await provider.initialize();

    final prefs = await SharedPreferences.getInstance();
    expect(provider.selectedSchool?.uuid, 'school-2');
    expect(prefs.getString('selected_school_uuid'), 'school-2');
    expect(prefs.getString('last_selected_school_uuid'), 'school-2');
    provider.dispose();
  });

  test('stale last-school preference is ignored and removed', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token',
      'last_selected_school_uuid': 'stale-school',
    });
    final provider = AuthProvider(api: _BootstrapApi());

    await provider.initialize();

    final prefs = await SharedPreferences.getInstance();
    expect(provider.selectedSchool, isNull);
    expect(prefs.getString('selected_school_uuid'), isNull);
    expect(prefs.getString('last_selected_school_uuid'), isNull);
    provider.dispose();
  });

  test('last-school preference without current access is ignored', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'token',
      'last_selected_school_uuid': 'school-2',
    });
    final provider = AuthProvider(
      api: _BootstrapApi(allowedSchoolUuids: const ['school-1']),
    );

    await provider.initialize();

    final prefs = await SharedPreferences.getInstance();
    expect(provider.selectedSchool, isNull);
    expect(prefs.getString('selected_school_uuid'), isNull);
    expect(prefs.getString('last_selected_school_uuid'), isNull);
    provider.dispose();
  });

  test(
    'logout clears credentials and active school but retains metadata',
    () async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'token',
        'selected_school_uuid': 'school-1',
      });
      final provider = AuthProvider(api: _BootstrapApi());
      await provider.initialize();

      await provider.logout();

      final prefs = await SharedPreferences.getInstance();
      expect(provider.isAuthenticated, isFalse);
      expect(provider.selectedSchool, isNull);
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('selected_school_uuid'), isNull);
      expect(prefs.getString('last_selected_school_uuid'), 'school-1');
      provider.dispose();
    },
  );

  test(
    'school and access requests run concurrently after identity loads',
    () async {
      SharedPreferences.setMockInitialValues({'access_token': 'token'});
      final schoolsGate = Completer<void>();
      final accessGate = Completer<void>();
      final schoolsStarted = Completer<void>();
      final accessStarted = Completer<void>();
      final provider = AuthProvider(
        api: _BootstrapApi(
          schoolsGate: schoolsGate,
          accessGate: accessGate,
          schoolsStarted: schoolsStarted,
          accessStarted: accessStarted,
        ),
      );

      final initialization = provider.initialize();
      await Future.wait([schoolsStarted.future, accessStarted.future]);

      schoolsGate.complete();
      accessGate.complete();
      await initialization;

      expect(provider.schools, hasLength(2));
      expect(provider.accesses, hasLength(2));
      provider.dispose();
    },
  );
}
