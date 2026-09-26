import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/screens/card_designer_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/design_document_view.dart';

void main() {
  Future<void> applyResizeStrategy(
    WidgetTester tester,
    String strategyLabel,
  ) async {
    await tester.pumpAndSettle();
    expect(
      find.text('How should existing elements be adjusted?'),
      findsOneWidget,
    );
    await tester.tap(find.text(strategyLabel));
    await tester.tap(find.byKey(const Key('canvas-resize-apply')));
    await tester.pumpAndSettle();
  }

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
    await tester.tap(find.byKey(const Key('toggle-properties')));
    await tester.tap(find.byKey(const Key('toggle-layers')));
    await tester.pump();
    expect(find.byKey(const Key('designer-canvas')), findsOneWidget);
    expect(find.byKey(const Key('canvas-properties')), findsOneWidget);
    expect(
      find.byKey(const Key('designer-save')).evaluate().single.widget,
      isA<TextButton>(),
    );

    final initialLayers = CardTemplate.uploadedDesign.document.elements.length;
    final initialElements = CardTemplate.uploadedDesign.document.elements;
    await tester.enterText(find.byKey(const Key('canvas-width')), '100');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await applyResizeStrategy(tester, 'Keep positions');
    await tester.enterText(find.byKey(const Key('canvas-height')), '70');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await applyResizeStrategy(tester, 'Keep positions');
    var canvas = tester.widget<DesignDocumentView>(
      find.byKey(const Key('designer-canvas')),
    );
    expect(canvas.document.canvas.width, 100);
    expect(canvas.document.canvas.height, 70);
    expect(canvas.document.canvas.orientation, 'landscape');
    expect(canvas.document.elements.first.x, initialElements.first.x);
    expect(canvas.document.elements.first.y, initialElements.first.y);
    expect(canvas.document.elements.first.width, initialElements.first.width);
    expect(canvas.document.elements.first.height, initialElements.first.height);

    await tester.tap(find.byKey(const Key('add-text')));
    await tester.pump();
    expect(find.byKey(const Key('element-properties')), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(savedBody?['design']['canvas']['width'], 100);
    expect(savedBody?['design']['canvas']['height'], 70);
    expect(
      (savedBody?['design']['elements'] as List).length,
      initialLayers + 1,
    );
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('canvas preset and orientation controls stay consistent', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/student-fields')) {
        return http.Response('[]', 200);
      }
      return http.Response('{}', 404);
    });
    final api = ApiService(client: client, baseUrl: 'http://test');
    addTearDown(api.dispose);
    final custom = CardTemplate.uploadedDesign.copyWith(
      document: CardTemplate.uploadedDesign.document.copyWith(
        canvas: const DesignCanvas(
          width: 100,
          height: 70,
          orientation: 'landscape',
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: CardDesignerScreen(
          schoolUuid: 'school',
          api: api,
          initialTemplate: custom,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Continue anyway'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('toggle-properties')));
    await tester.pump();
    expect(find.byKey(const Key('canvas-properties')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('canvas-preset')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CR80 / ID-1 — 85.60 × 53.98 mm').last);
    await applyResizeStrategy(tester, 'Keep positions');
    var canvas = tester.widget<DesignDocumentView>(
      find.byKey(const Key('designer-canvas')),
    );
    expect(canvas.document.canvas.width, 85.6);
    expect(canvas.document.canvas.height, 53.98);
    expect(canvas.document.canvas.orientation, 'landscape');

    await tester.tap(
      find.byKey(const ValueKey('canvas-orientation-landscape')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portrait').last);
    await applyResizeStrategy(tester, 'Keep positions');
    canvas = tester.widget<DesignDocumentView>(
      find.byKey(const Key('designer-canvas')),
    );
    expect(canvas.document.canvas.width, 53.98);
    expect(canvas.document.canvas.height, 85.6);
    expect(canvas.document.canvas.orientation, 'portrait');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'orientation strategy is one undo entry and redo restores geometry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/student-fields')) {
          return http.Response('[]', 200);
        }
        return http.Response('{}', 404);
      });
      final api = ApiService(client: client, baseUrl: 'http://test');
      addTearDown(api.dispose);
      final original = CardTemplate.uploadedDesign;

      await tester.pumpWidget(
        MaterialApp(
          home: CardDesignerScreen(
            schoolUuid: 'school',
            api: api,
            initialTemplate: original,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('toggle-properties')));
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('canvas-orientation-landscape')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Portrait').last);
      await applyResizeStrategy(tester, 'Scale proportionally');

      DesignDocumentView view() => tester.widget<DesignDocumentView>(
        find.byKey(const Key('designer-canvas')),
      );

      var transformed = view().document;
      expect(transformed.canvas.orientation, 'portrait');
      expect(
        transformed.elements.last.rotation,
        original.document.elements.last.rotation,
      );
      expect(find.text('Unsaved changes'), findsOneWidget);
      expect(
        transformed.elements.last.y,
        closeTo(
          original.document.elements.last.y *
              transformed.canvas.height /
              original.document.canvas.height,
          .001,
        ),
      );

      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      expect(view().document.toJson(), original.document.toJson());
      expect(find.text('Saved'), findsOneWidget);

      await tester.tap(find.byTooltip('Redo'));
      await tester.pump();
      expect(view().document.toJson(), transformed.toJson());
      expect(find.text('Unsaved changes'), findsOneWidget);
    },
  );

  testWidgets('canvas change with no elements does not prompt', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/student-fields')) {
        return http.Response('[]', 200);
      }
      return http.Response('{}', 404);
    });
    final api = ApiService(client: client, baseUrl: 'http://test');
    addTearDown(api.dispose);
    final empty = CardTemplate(
      name: 'Empty',
      document: DesignDocument(
        canvas: const DesignCanvas(),
        elements: const [],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CardDesignerScreen(
          schoolUuid: 'school',
          api: api,
          initialTemplate: empty,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('toggle-properties')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('canvas-orientation-landscape')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Portrait').last);
    await tester.pumpAndSettle();
    expect(
      find.text('How should existing elements be adjusted?'),
      findsNothing,
    );
    final canvas = tester.widget<DesignDocumentView>(
      find.byKey(const Key('designer-canvas')),
    );
    expect(canvas.document.canvas.orientation, 'portrait');
  });

  testWidgets('invalid canvas dimensions are rejected without prompting', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/student-fields')) {
        return http.Response('[]', 200);
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
    await tester.tap(find.byKey(const Key('toggle-properties')));
    await tester.pump();
    final original = CardTemplate.uploadedDesign.document.canvas;

    await tester.enterText(find.byKey(const Key('canvas-width')), 'NaN');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(
      find.text('How should existing elements be adjusted?'),
      findsNothing,
    );
    expect(find.byKey(const Key('canvas-validation-error')), findsNothing);

    await tester.enterText(find.byKey(const Key('canvas-width')), '5');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byKey(const Key('canvas-validation-error')), findsOneWidget);
    final canvas = tester.widget<DesignDocumentView>(
      find.byKey(const Key('designer-canvas')),
    );
    expect(canvas.document.canvas.toJson(), original.toJson());
    expect(
      find.text('How should existing elements be adjusted?'),
      findsNothing,
    );
  });

  testWidgets('Class + Section is available as a student identity field', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final client = MockClient((request) async {
      if (request.url.path.endsWith('/student-fields')) {
        return http.Response('[]', 200);
      }

      if (request.url.path.endsWith('/profile')) {
        return http.Response('{}', 404);
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

    // Open the properties inspector.
    await tester.tap(find.byKey(const Key('toggle-properties')));
    await tester.pump();

    // Add a new identity-field element.
    await tester.tap(find.byKey(const Key('add-student-field')));
    await tester.pump();

    final identityFieldControl = find.byWidgetPredicate((widget) {
      final key = widget.key;

      return key is ValueKey<String> && key.value.startsWith('student-field-');
    });

    expect(identityFieldControl, findsOneWidget);

    final dropdown = find.descendant(
      of: identityFieldControl,
      matching: find.byWidgetPredicate(
        (widget) => widget is DropdownButtonFormField<String>,
      ),
    );

    expect(dropdown, findsOneWidget);

    final dropdownButton = find.descendant(
      of: dropdown,
      matching: find.byWidgetPredicate(
        (widget) => widget is DropdownButton<String>,
      ),
    );

    expect(dropdownButton, findsOneWidget);

    final fieldDropdown = tester.widget<DropdownButton<String>>(
      dropdownButton,
    );

    final classSectionItem = fieldDropdown.items!.singleWhere(
      (item) => item.value == 'class_section',
    );

    expect(classSectionItem.child, isA<Text>());
    expect((classSectionItem.child as Text).data, 'Class + Section');

    // Select the combined binding through the same callback used by the UI.
    fieldDropdown.onChanged?.call('class_section');
    await tester.pump();

    final canvas = tester.widget<DesignDocumentView>(
      find.byKey(const Key('designer-canvas')),
    );

    expect(
      canvas.document.elements.where(
        (element) =>
            element.type == DesignElementType.boundText &&
            element.data['field'] == 'class_section',
      ),
      hasLength(1),
    );
  });

  test('canvas background transform properties round-trip', () {
    final document = DesignDocument.fromJson({
      'schema_version': 2,
      'canvas': {
        'width': 85.6,
        'height': 53.98,
        'orientation': 'landscape',
        'background_color': '#FFFFFF',
        'background_image': 'https://example.test/background.png',
        'background_opacity': 0.4,
        'background_scale': 2.25,
        'background_offset_x': 3.5,
        'background_offset_y': -2.0,
      },
      'elements': <dynamic>[],
      'settings': <String, dynamic>{},
    });
    expect(document.canvas.backgroundOpacity, 0.4);
    expect(document.canvas.backgroundScale, 2.25);
    expect(document.canvas.backgroundOffsetX, 3.5);
    expect(document.canvas.backgroundOffsetY, -2.0);
    expect(document.toJson()['canvas'], containsPair('background_scale', 2.25));
  });

}
