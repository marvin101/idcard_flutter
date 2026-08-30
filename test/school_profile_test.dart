import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/school_profile.dart';
import 'package:idcard_flutter/providers/school_profile_provider.dart';
import 'package:idcard_flutter/screens/school_profile_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:image_picker/image_picker.dart';

Map<String, dynamic> _profileJson({
  String schoolName = 'Campus School',
  String? logoPath,
  String? logoUrl,
}) => {
  'uuid': 'school-1',
  'school_code': 'CAMPUS-1',
  'school_name': schoolName,
  'email': 'office@example.test',
  'phone': '1234567890',
  'website': 'https://school.example.test',
  'address': '1 Campus Road',
  'city': 'Pune',
  'district': 'Pune',
  'state': 'Maharashtra',
  'country': 'India',
  'postal_code': '411001',
  'logo_path': logoPath,
  'logo_url': logoUrl,
  'principal_name': 'Dr Principal',
  'is_active': true,
};

Future<void> _waitForProvider(SchoolProfileProvider provider) async {
  if (!provider.loading && provider.profile != null) return;
  final completer = Completer<void>();
  void listener() {
    if (!provider.loading && !completer.isCompleted) completer.complete();
  }

  provider.addListener(listener);
  await completer.future.timeout(const Duration(seconds: 2));
  provider.removeListener(listener);
}

void main() {
  test('profile edit permission follows platform and school admin roles', () {
    expect(
      canEditSchoolProfile(isPlatformAdmin: true, schoolRole: null),
      isTrue,
    );
    expect(
      canEditSchoolProfile(isPlatformAdmin: false, schoolRole: 'school_admin'),
      isTrue,
    );
    for (final role in ['card_operator', 'teacher', 'staff']) {
      expect(
        canEditSchoolProfile(isPlatformAdmin: false, schoolRole: role),
        isFalse,
      );
    }
  });

  test('provider loads school profile data', () async {
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/schools/school-1/profile');
        return http.Response(jsonEncode(_profileJson()), 200);
      }),
    );
    final provider = SchoolProfileProvider(
      api: api,
      schoolUuid: 'school-1',
      canEdit: true,
    );

    await _waitForProvider(provider);

    expect(provider.error, isNull);
    expect(provider.profile?.schoolName, 'Campus School');
    expect(provider.profile?.principalName, 'Dr Principal');
    provider.dispose();
    api.dispose();
  });

  test('authorized save serializes only editable profile fields', () async {
    late Map<String, dynamic> patchBody;
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        if (request.method == 'GET') {
          return http.Response(jsonEncode(_profileJson()), 200);
        }
        patchBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode(
            _profileJson(schoolName: patchBody['school_name'] as String),
          ),
          200,
        );
      }),
    );
    final provider = SchoolProfileProvider(
      api: api,
      schoolUuid: 'school-1',
      canEdit: true,
    );
    await _waitForProvider(provider);

    final saved = await provider.save(
      provider.profile!.copyWith(
        schoolName: 'Updated School',
        email: 'new@example.test',
        phone: provider.profile!.phone,
        website: provider.profile!.website,
        address: provider.profile!.address,
        city: provider.profile!.city,
        district: provider.profile!.district,
        state: provider.profile!.state,
        country: provider.profile!.country,
        postalCode: provider.profile!.postalCode,
        principalName: provider.profile!.principalName,
      ),
    );

    expect(saved, isTrue);
    expect(patchBody['school_name'], 'Updated School');
    expect(patchBody['email'], 'new@example.test');
    expect(patchBody, isNot(contains('school_code')));
    expect(patchBody, isNot(contains('logo_path')));
    provider.dispose();
    api.dispose();
  });

  test('logo upload is a typed multipart request', () async {
    late http.Request captured;
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(
            _profileJson(
              logoPath: 'schools/school-1/logos/new.png',
              logoUrl: 'https://media.test/new.png',
            ),
          ),
          200,
        );
      }),
    );
    final logo = XFile.fromData(
      Uint8List.fromList(const [137, 80, 78, 71]),
      name: 'crest.png',
      mimeType: 'image/png',
    );

    final result = await api.uploadSchoolLogo(
      schoolUuid: 'school-1',
      logo: logo,
    );

    final multipartBody = latin1.decode(captured.bodyBytes);
    expect(captured.method, 'POST');
    expect(captured.url.path, '/schools/school-1/logo');
    expect(
      captured.headers['content-type'],
      startsWith('multipart/form-data;'),
    );
    expect(multipartBody, contains('name="logo"'));
    expect(multipartBody, contains('filename="school_logo.png"'));
    expect(multipartBody.toLowerCase(), contains('content-type: image/png'));
    expect(result.logoPath, 'schools/school-1/logos/new.png');
    api.dispose();
  });

  testWidgets('non-admin profile is read-only and hides logo/save controls', (
    tester,
  ) async {
    final api = ApiService(baseUrl: 'https://example.test');
    final provider = SchoolProfileProvider(
      api: api,
      schoolUuid: 'school-1',
      canEdit: false,
      autoLoad: false,
    )..profile = SchoolProfile.fromJson(_profileJson());

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolProfileScreen(
          schoolUuid: 'school-1',
          schoolName: 'Campus School',
          api: api,
          canEdit: false,
          provider: provider,
        ),
      ),
    );

    expect(
      find.text('Profile details are read-only for your school role.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('choose-school-logo')), findsNothing);
    expect(find.byKey(const Key('save-school-profile')), findsNothing);
    expect(find.text('CAMPUS-1'), findsOneWidget);
    provider.dispose();
    api.dispose();
  });

  testWidgets('profile loading errors are displayed with retry', (
    tester,
  ) async {
    final api = ApiService(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'Profile service unavailable.'}),
          503,
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SchoolProfileScreen(
          schoolUuid: 'school-1',
          schoolName: 'Campus School',
          api: api,
          canEdit: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile service unavailable.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    api.dispose();
  });
}
