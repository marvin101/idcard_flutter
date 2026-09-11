import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/models/api_personnel.dart';
import 'package:idcard_flutter/services/api_service.dart';

Map<String, dynamic> _personnelJson({String type = 'teacher'}) => {
  'uuid': '26b15523-5342-48ca-9e9a-19d38c278005',
  'personnel_type': type,
  'employee_no': 'EMP-7',
  'full_name': 'Asha Singh',
  'designation': 'Teacher',
  'department': 'Science',
  'dob': '1990-02-03',
  'gender': 'Female',
  'blood_group': 'A+',
  'mobile': '9000000000',
  'email': 'asha@example.test',
  'address': 'Ranchi',
  'photo_path': null,
  'linked_user_uuid': null,
  'verification_status': 'verified',
  'lifecycle_status': 'ready_for_print',
  'correction_note': null,
  'verified_at': '2026-09-11T10:00:00Z',
  'verified_by_user_uuid': null,
  'verified_by_name': 'Administrator',
  'printed_at': null,
  'printed_by_user_uuid': null,
  'printed_by_name': null,
  'print_count': 0,
  'is_active': true,
  'created_at': '2026-09-11T09:00:00Z',
  'updated_at': '2026-09-11T10:00:00Z',
  'custom_fields': const [],
};

void main() {
  test('personnel model parses lifecycle and identity type', () {
    final personnel = ApiPersonnel.fromJson(_personnelJson());
    expect(personnel.personnelType, PersonnelType.teacher);
    expect(personnel.employeeNo, 'EMP-7');
    expect(personnel.isVerified, isTrue);
    expect(personnel.isPrinted, isFalse);
    expect(personnel.dob, DateTime(1990, 2, 3));
  });

  test('personnel list is type scoped and parses pagination', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/schools/school-1/personnel');
      expect(request.url.queryParameters['personnel_type'], 'staff');
      expect(request.url.queryParameters['search'], 'Asha');
      expect(request.url.queryParameters['verification_status'], 'verified');
      expect(request.url.queryParameters['printed'], 'false');
      return http.Response(
        jsonEncode({
          'items': [_personnelJson(type: 'staff')],
          'total': 1,
          'offset': 0,
          'limit': 100,
          'has_more': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: client, baseUrl: 'https://example.test');
    final page = await api.getPersonnel(
      schoolUuid: 'school-1',
      personnelType: PersonnelType.staff,
      search: ' Asha ',
      verificationStatus: 'verified',
      printed: false,
    );
    expect(page.total, 1);
    expect(page.items.single.personnelType, PersonnelType.staff);
    api.dispose();
  });

  test('personnel create sends the selected record type', () async {
    late Map<String, dynamic> body;
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/schools/school-1/personnel');
      body = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode(_personnelJson()),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiService(client: client, baseUrl: 'https://example.test');
    await api.createPersonnel(
      schoolUuid: 'school-1',
      personnelType: PersonnelType.teacher,
      employeeNo: 'EMP-7',
      fullName: 'Asha Singh',
    );
    expect(body['personnel_type'], 'teacher');
    expect(body['employee_no'], 'EMP-7');
    api.dispose();
  });

  test('personnel routes are protected and history UUID round-trips', () {
    const uuid = '26b15523-5342-48ca-9e9a-19d38c278005';
    final route = AppRoutes.personnelHistory(uuid);
    expect(AppRoutes.isProtected(AppRoutes.teachers), isTrue);
    expect(AppRoutes.isProtected(AppRoutes.staff), isTrue);
    expect(AppRoutes.isProtected(route), isTrue);
    expect(AppRoutes.personnelUuidFromHistory(route), uuid);
  });
}
