import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/auth_models.dart';

void main() {
  test('self-profile fields parse without affecting authorization flags', () {
    final user = AuthUser.fromJson({
      'uuid': 'user-1',
      'username': 'ada',
      'full_name': 'Ada Lovelace',
      'email': 'ada@example.com',
      'mobile': '+44 20 1234 5678',
      'profile_photo_url': 'https://example.com/avatar.png',
      'created_at': '2026-01-02T03:04:05Z',
      'updated_at': '2026-01-03T03:04:05Z',
      'last_login': '2026-01-04T03:04:05Z',
      'school_contexts': [
        {
          'school_uuid': 'school-1',
          'school_name': 'Test School',
          'role': 'teacher',
        },
      ],
      'is_platform_admin': false,
      'is_active': true,
    });

    expect(user.initials, 'AL');
    expect(user.profilePhotoUrl, 'https://example.com/avatar.png');
    expect(user.schoolContexts.single.schoolName, 'Test School');
    expect(user.isPlatformAdministrator, isFalse);
  });

  test('current and legacy school-admin roles are recognized', () {
    const current = SchoolAccess(
      schoolUuid: 'school-1',
      schoolName: 'School One',
      role: 'school_admin',
    );
    const legacy = SchoolAccess(
      schoolUuid: 'school-2',
      schoolName: 'School Two',
      role: 'admin',
    );
    const teacher = SchoolAccess(
      schoolUuid: 'school-3',
      schoolName: 'School Three',
      role: 'teacher',
    );
    const cardOperator = SchoolAccess(
      schoolUuid: 'school-4',
      schoolName: 'School Four',
      role: 'card_operator',
    );

    expect(current.isSchoolAdministrator, isTrue);
    expect(legacy.isSchoolAdministrator, isTrue);
    expect(teacher.isSchoolAdministrator, isFalse);
    expect(cardOperator.isCardOperator, isTrue);
    expect(teacher.isCardOperator, isFalse);
  });
}
