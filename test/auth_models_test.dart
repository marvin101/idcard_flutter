import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/auth_models.dart';

void main() {
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

    expect(current.isSchoolAdministrator, isTrue);
    expect(legacy.isSchoolAdministrator, isTrue);
    expect(teacher.isSchoolAdministrator, isFalse);
  });
}
