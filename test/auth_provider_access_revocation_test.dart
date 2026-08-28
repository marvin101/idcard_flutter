import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/auth_models.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AccessApi extends ApiService {
  _AccessApi({required this.schools, required this.accesses});

  final List<dynamic> schools;
  final List<dynamic> accesses;

  @override
  void setToken(String? token) {}

  @override
  Future<Map<String, dynamic>> getMe() async => {
    'uuid': 'user-1',
    'username': 'teacher',
    'full_name': 'Test Teacher',
    'platform_role': null,
    'is_platform_admin': false,
    'is_active': true,
  };

  @override
  Future<List<dynamic>> getSchools() async => schools;

  @override
  Future<List<dynamic>> getUserSchools(String userUuid) async => accesses;

  @override
  void dispose() {}
}

Map<String, dynamic> _school(String uuid, String name) => {
  'uuid': uuid,
  'school_code': uuid.toUpperCase(),
  'school_name': name,
  'is_active': true,
};

Map<String, dynamic> _access(String uuid, String name, String role) => {
  'school_uuid': uuid,
  'school_name': name,
  'role': role,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialization clears a saved school after access is revoked', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'test-token',
      'selected_school_uuid': 'revoked-school',
    });
    final provider = AuthProvider(
      api: _AccessApi(
        schools: [
          _school('school-2', 'Second School'),
          _school('school-3', 'Third School'),
        ],
        accesses: [
          _access('school-2', 'Second School', 'teacher'),
          _access('school-3', 'Third School', 'teacher'),
        ],
      ),
    );

    await provider.initialize();

    expect(provider.isAuthenticated, isTrue);
    expect(provider.selectedSchool, isNull);
    expect(
      provider.schools.map((school) => school.uuid),
      isNot(contains('revoked-school')),
    );
    expect(provider.selectedSchoolAccess, isNull);
    provider.dispose();
  });

  test('selecting a school without access is rejected', () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'test-token',
    });
    final provider = AuthProvider(
      api: _AccessApi(
        schools: [
          _school('school-2', 'Assigned School'),
          _school('school-3', 'Unassigned School'),
        ],
        accesses: [
          _access('school-2', 'Assigned School', 'teacher'),
        ],
      ),
    );
    await provider.initialize();

    expect(
      () => provider.selectSchool(
        const SchoolSummary(
          uuid: 'school-3',
          code: 'SCHOOL-3',
          name: 'Unassigned School',
          isActive: true,
        ),
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 403),
      ),
    );
    provider.dispose();
  });
}
