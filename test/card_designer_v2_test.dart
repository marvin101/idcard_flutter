import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/screens/card_designer_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';

void main() {
  testWidgets('add, undo, redo, dirty state, and v2 save payload work', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Map<String, dynamic>? savedBody;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/student-fields')) {
        return http.Response('[]', 200);
      }
      if (request.url.path.endsWith('/profile')) {
        return http.Response('{}', 404);
      }
      if (request.method == 'PUT' &&
          request.url.path.endsWith('/card-template')) {
        savedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            ...savedBody!,
            'uuid': 'template',
            'updated_at': '2026-09-03T00:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 404);
    });
    final api = ApiService(client: client, baseUrl: 'http://test');
    addTearDown(api.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: CardDesignerScreen(
          schoolUuid: 'school',
          api: api,
          initialTemplate: CardTemplate.uploadedDesign,
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('designer-canvas')), findsOneWidget);
    expect(
      find.byKey(const Key('designer-save')).evaluate().single.widget,
      isA<TextButton>(),
    );

    final initialLayers = CardTemplate.uploadedDesign.document.elements.length;
    await tester.tap(find.byKey(const Key('add-text')));
    await tester.pump();
    expect(find.byKey(const Key('designer-save-state')), findsOneWidget);
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.byType(ListTile), findsAtLeastNWidgets(initialLayers + 1));

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    await tester.tap(find.byTooltip('Redo'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('designer-save')));
    await tester.pumpAndSettle();

    expect(savedBody?['design']['schema_version'], 2);
    expect(
      (savedBody?['design']['elements'] as List).length,
      initialLayers + 1,
    );
    expect(find.text('Saved'), findsOneWidget);
  });
}
