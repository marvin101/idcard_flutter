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
}
