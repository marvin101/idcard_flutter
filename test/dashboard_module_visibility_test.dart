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

  test('card operators see student entry and ID-card tools', () {
    expect(
      dashboardModulesFor(
        isPlatformAdmin: false,
        schoolRole: 'card_operator',
        hasSelectedSchool: true,
      ),
      {
        DashboardModuleKind.schoolProfile,
        DashboardModuleKind.students,
        DashboardModuleKind.idCards,
      },
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
          DashboardModuleKind.schoolProfile,
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

  test('phone widths use a compact app-drawer grid', () {
    final phone = dashboardGridLayoutFor(360);
    expect(phone.compact, isTrue);
    expect(phone.columns, 3);
    expect(phone.mainAxisExtent, lessThan(120));

    final veryNarrow = dashboardGridLayoutFor(250);
    expect(veryNarrow.columns, 2);

    final desktop = dashboardGridLayoutFor(900);
    expect(desktop.compact, isFalse);
  });
}
