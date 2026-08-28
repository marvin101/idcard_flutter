import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/providers/auth_provider.dart';
import 'package:idcard_flutter/screens/login_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('login fields expose password-manager autofill hints', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.byType(AutofillGroup), findsOneWidget);
    final fields = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(fields.elementAt(0).autofillHints, contains(AutofillHints.username));
    expect(fields.elementAt(1).autofillHints, contains(AutofillHints.password));
  });
}
