import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/screens/school_user_assignment_screen.dart';

void main() {
  testWidgets('shows the school user directory', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SchoolUserAssignmentScreen(
          schoolUuid: 'school-uuid',
          schoolName: 'Greenfield Public School',
          useDemoData: true,
        ),
      ),
    );

    expect(find.text('User assignments'), findsOneWidget);
    expect(find.text('Greenfield Public School'), findsOneWidget);
    expect(find.text('Anita Sharma'), findsOneWidget);
    expect(find.text('Search name, email, or designation'), findsOneWidget);
  });

  testWidgets('school administrators cannot select elevated roles', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SchoolUserAssignmentScreen(
          schoolUuid: 'school-uuid',
          initialUsers: [
            SchoolUserAssignment(
              id: 'user-1',
              name: 'Arjun Kapoor',
              username: 'arjun.kapoor',
            ),
          ],
        ),
      ),
    );

    final roleDropdown = find.byType(DropdownButtonFormField<SchoolRole>);

    await tester.ensureVisible(roleDropdown);
    await tester.tap(roleDropdown);
    await tester.pumpAndSettle();

    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Staff'), findsOneWidget);
    expect(find.text('School administrator'), findsNothing);
    expect(find.text('Card operator'), findsNothing);
  });
}
