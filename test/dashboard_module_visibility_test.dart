import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/screens/dashboard_screen.dart';

void main() {
  test('administrators see every module for a selected school', () {
    expect(
      dashboardModulesFor(
        isPlatformAdmin: false,
        schoolRole: 'school_admin',
        hasSelectedSchool: true,
      ),
      DashboardModuleKind.values.toSet(),
    );
  });

  test('card operators see only student entry', () {
    expect(
      dashboardModulesFor(
        isPlatformAdmin: false,
        schoolRole: 'card_operator',
        hasSelectedSchool: true,
      ),
      {DashboardModuleKind.students},
    );
  });

  test('teachers and staff see only academic structure modules', () {
    for (final role in ['teacher', 'staff']) {
      expect(
        dashboardModulesFor(
          isPlatformAdmin: false,
          schoolRole: role,
          hasSelectedSchool: true,
        ),
        {
          DashboardModuleKind.academicSessions,
          DashboardModuleKind.classesAndSections,
        },
      );
    }
  });

  test('missing selection or role exposes no modules', () {
    expect(
      dashboardModulesFor(
        isPlatformAdmin: false,
        schoolRole: null,
        hasSelectedSchool: true,
      ),
      isEmpty,
    );
    expect(
      dashboardModulesFor(
        isPlatformAdmin: true,
        schoolRole: null,
        hasSelectedSchool: false,
      ),
      isEmpty,
    );
  });
}
