import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/screens/card_designer_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/design_document_view.dart';
import 'package:idcard_flutter/widgets/designer_colour_field.dart';

void main() {
  testWidgets('No border is only offered by opted-in colour fields', (t) async {
    var colour = '#24345F';
    var none = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesignerColourField(
            fieldKey: const Key('border-field'),
            ownerId: 'a',
            value: colour,
            decoration: const InputDecoration(labelText: 'Border colour'),
            recentColours: const [],
            allowNone: true,
            noneSelected: none,
            onNone: () => none = true,
            onChanged: (value) => colour = value,
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const Key('choose-border-field')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('colour-no-border')), findsOneWidget);
    await t.tap(find.byKey(const Key('colour-no-border')));
    await t.pumpAndSettle();
    expect(none, isTrue);
    expect(colour, '#24345F');
  });

  final types = <DesignElementType>[
    DesignElementType.studentPhoto,
    DesignElementType.schoolLogo,
    DesignElementType.principalSignature,
    DesignElementType.rectangle,
    DesignElementType.roundedRectangle,
    DesignElementType.ellipse,
    DesignElementType.circle,
    DesignElementType.triangle,
    DesignElementType.bloodDrop,
  ];

  testWidgets('media and shapes preserve border colour and restore width', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(1600, 1800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final api = ApiService(
      baseUrl: 'http://test',
      client: MockClient(
        (request) async => http.Response(
          request.url.path.endsWith('/student-fields') ? '[]' : '{}',
          request.url.path.endsWith('/student-fields') ? 200 : 404,
        ),
      ),
    );
    addTearDown(api.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: CardDesignerScreen(
          schoolUuid: 'school',
          api: api,
          initialTemplate: CardTemplate(
            name: 'Borders',
            document: DesignDocument(
              canvas: const DesignCanvas(width: 100, height: 80),
              settings: const {'snap_enabled': false, 'grid_enabled': false},
              elements: [
                for (var i = 0; i < types.length; i++)
                  DesignElement(
                    id: 'border-$i',
                    type: types[i],
                    x: 5,
                    y: 5,
                    width: 20,
                    height: 20,
                    style: const {
                      'border_color': '#24345F',
                      'border_width': 1.25,
                      'fill_color': '#FFFFFF',
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('toggle-layers')));
    await t.tap(find.byKey(const Key('toggle-properties')));
    await t.pumpAndSettle();
    DesignDocumentView view() =>
        t.widget<DesignDocumentView>(find.byKey(const Key('designer-canvas')));
    DesignElement element(int i) => view().document.elements[i];
    for (var i = 0; i < types.length; i++) {
      view().onSelect!('border-$i');
      await t.pump();
      t
          .widget<IconButton>(
            find.byKey(const Key('choose-property-border-colour-(hex)')),
          )
          .onPressed!();
      await t.pumpAndSettle();
      t
          .widget<TextButton>(find.byKey(const Key('colour-no-border')))
          .onPressed!();
      await t.pumpAndSettle();
      expect(element(i).style['border_width'], 0.0, reason: '${types[i]}');
      expect(element(i).style['border_color'], '#24345F');
      expect(
        t
            .widget<TextFormField>(
              find.byKey(const Key('property-border-width')),
            )
            .controller!
            .text,
        '0.00',
      );
      t
          .widget<IconButton>(
            find.byKey(const Key('choose-property-border-colour-(hex)')),
          )
          .onPressed!();
      await t.pumpAndSettle();
      t
          .widget<IconButton>(find.byKey(const Key('palette-#000000')))
          .onPressed!();
      await t.pump();
      t
          .widget<FilledButton>(find.byKey(const Key('colour-apply')))
          .onPressed!();
      await t.pumpAndSettle();
      expect(element(i).style['border_color'], '#000000');
      expect(element(i).style['border_width'], 1.25);
      t
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('property-border-width')),
              matching: find.byType(TextField),
            ),
          )
          .onSubmitted!('0');
      await t.pump();
      expect(element(i).style['border_width'], 0.0);
      t
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('property-border-width')),
              matching: find.byType(TextField),
            ),
          )
          .onSubmitted!('2');
      await t.pump();
      expect(element(i).style['border_width'], 2.0);
      expect(element(i).style['border_color'], '#000000');
    }
  });
}
