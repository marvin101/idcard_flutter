import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/app_routes.dart';
import 'package:idcard_flutter/models/api_student.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_bindings.dart';
import 'package:idcard_flutter/models/public_verification.dart';
import 'package:idcard_flutter/navigation/app_router.dart';
import 'package:idcard_flutter/screens/public_student_verification_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/authenticated_shell.dart';

class _FakeApi extends ApiService {
  _FakeApi({this.failure});

  final Object? failure;
  int loads = 0;

  @override
  Future<PublicStudentVerification> getPublicStudentVerification(
    String token,
  ) async {
    loads += 1;
    if (failure != null) throw failure!;
    return PublicStudentVerification(
      schoolName: 'Campus School',
      schoolCode: 'SCH-01',
      verificationStatus: 'verified',
      lifecycleStatus: 'ready_for_print',
      signatureVerified: true,
      credentialExpiresAt: DateTime.utc(2027, 9, 10),
      fields: [
        PublicVerificationValue(
          key: 'full_name',
          label: 'Full name',
          value: 'Asha Singh',
        ),
        PublicVerificationValue(key: 'class', label: 'Class', value: '10'),
      ],
    );
  }
}

void main() {
  test('verification route is anonymous and token-safe', () {
    final route = AppRoutes.publicVerification('opaque/token');
    expect(route, '/verify/opaque%2Ftoken');
    expect(AppRoutes.isPublicVerification(route), isTrue);
    expect(AppRoutes.publicVerificationToken(route), 'opaque/token');
    expect(AppRoutes.isProtected(route), isFalse);
  });

  test('route parser preserves direct and hash verification links', () async {
    const parser = AppRouteInformationParser();
    final direct = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/verify/opaque-token')),
    );
    final hash = await parser.parseRouteInformation(
      RouteInformation(uri: Uri.parse('/#/verify/opaque-token')),
    );
    expect(direct.location, '/verify/opaque-token');
    expect(hash.location, '/verify/opaque-token');
  });

  test('public verification API sends no authorization header', () async {
    late http.Request request;
    final api = ApiService(
      baseUrl: 'https://api.example.test',
      client: MockClient((value) async {
        request = value;
        return http.Response(
          jsonEncode({
            'school': {
              'school_name': 'Campus School',
              'school_code': 'SCH-01',
              'logo_url': null,
            },
            'verification_status': 'verified',
            'lifecycle_status': 'ready_for_print',
            'verified_at': null,
            'photo_url': null,
            'credential_status': 'active',
            'credential_version': 3,
            'credential_issued_at': '2026-09-10T00:00:00Z',
            'credential_expires_at': '2027-09-10T00:00:00Z',
            'signature_verified': true,
            'fields': [
              {'key': 'full_name', 'label': 'Full name', 'value': 'Asha Singh'},
            ],
          }),
          200,
        );
      }),
    )..setToken('must-not-leak');

    final view = await api.getPublicStudentVerification('opaque/token');
    expect(request.url.path, '/public/verifications/opaque%2Ftoken');
    expect(request.headers.containsKey('authorization'), isFalse);
    expect(view.schoolName, 'Campus School');
    expect(view.fields.single.value, 'Asha Singh');
    expect(view.signatureVerified, isTrue);
    expect(view.credentialVersion, 3);
    expect(view.credentialExpiresAt, DateTime.utc(2027, 9, 10));
  });

  test('student verification URL binds directly into QR content', () {
    const student = ApiStudent(
      uuid: 'student',
      sessionUuid: 'session',
      classUuid: 'class',
      sectionUuid: 'section',
      admissionNo: 'ADM-1',
      fullName: 'Asha Singh',
      isActive: true,
      verificationUrl: 'https://campus.example/verify/token',
    );
    const element = DesignElement(
      id: 'verification-qr',
      type: DesignElementType.qrCode,
      x: 0,
      y: 0,
      width: 20,
      height: 20,
      data: {'field': 'verification_url'},
    );
    expect(
      const DesignBindings(student: student).text(element),
      'https://campus.example/verify/token',
    );
  });

  testWidgets('verified record renders outside authenticated UI', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublicStudentVerificationScreen(token: 'token', api: _FakeApi()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AuthenticatedShell), findsNothing);
    expect(find.text('Campus School'), findsOneWidget);
    expect(find.text('Verified student record'), findsOneWidget);
    expect(find.text('Asha Singh'), findsOneWidget);
    expect(find.byKey(const Key('signed-credential-status')), findsOneWidget);
    expect(
      find.textContaining('Cryptographic signature verified'),
      findsOneWidget,
    );
  });

  test('credential settings and student link parse lifecycle metadata', () {
    final settings = PublicVerificationSettings.fromJson({
      'enabled': true,
      'fields': ['full_name'],
      'validity_days': 180,
      'available_fields': const [],
    });
    final link = StudentVerificationLink.fromJson({
      'enabled': true,
      'verification_url': 'https://campus.example/verify/signed',
      'credential_status': 'active',
      'credential_version': 4,
      'issued_at': '2026-09-11T00:00:00Z',
      'expires_at': '2027-03-10T00:00:00Z',
    });

    expect(settings.validityDays, 180);
    expect(link.credentialVersion, 4);
    expect(link.credentialStatus, 'active');
    expect(link.expiresAt, DateTime.utc(2027, 3, 10));
  });

  test('verification settings API sends credential validity', () async {
    late http.Request request;
    final api = ApiService(
      baseUrl: 'https://api.example.test',
      client: MockClient((value) async {
        request = value;
        return http.Response(
          jsonEncode({
            'enabled': true,
            'fields': ['full_name'],
            'validity_days': 90,
            'available_fields': const [],
          }),
          200,
        );
      }),
    )..setToken('admin-token');

    await api.updatePublicVerificationSettings(
      schoolUuid: 'school',
      enabled: true,
      fields: const ['full_name'],
      validityDays: 90,
    );

    expect(jsonDecode(request.body)['validity_days'], 90);
  });

  testWidgets('unavailable verification link uses a generic state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PublicStudentVerificationScreen(
          token: 'bad',
          api: _FakeApi(failure: const ApiException(404, 'Not found')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('This verification link is unavailable.'), findsOneWidget);
  });
}
