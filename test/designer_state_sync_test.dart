import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/screens/card_designer_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/design_document_view.dart';

void main() {
  testWidgets('selection, edits, history and gestures share the live model', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    const a = DesignElement(
      id: 'a',
      type: DesignElementType.text,
      x: 2,
      y: 3,
      width: 30,
      height: 10,
      data: {'text': 'Kanke, Ranchi'},
      style: {
        'font_size': 3.0,
        'font_weight': 400,
        'alignment': 'left',
        'color': '#112233',
      },
    );
    const b = DesignElement(
      id: 'b',
      type: DesignElementType.text,
      x: 7,
      y: 18,
      width: 50,
      height: 12,
      rotation: 15,
      locked: true,
      visible: false,
      data: {'text': 'ANITA INTERMEDIATE COLLEGE'},
      style: {
        'font_size': 4.0,
        'font_weight': 700,
        'alignment': 'right',
        'color': '#445566',
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CardDesignerScreen(
          schoolUuid: 'school',
          api: api,
          initialTemplate: const CardTemplate(
            name: 'Sync',
            document: DesignDocument(
              canvas: DesignCanvas(),
              elements: [a, b],
              settings: {'snap_enabled': false, 'grid_enabled': false},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    DesignDocumentView view() => tester.widget<DesignDocumentView>(
      find.byKey(const Key('designer-canvas')),
    );
    DesignElement live() =>
        view().document.elements.firstWhere((e) => e.id == view().selectedId);
    Finder field(String name) => find.byKey(Key('property-$name'));
    String value(String name) =>
        tester.widget<TextFormField>(field(name)).controller!.text;
    Future<void> select(String id) async {
      view().onSelect!(id);
      await tester.pump();
    }

    Future<void> submit(String name, String text) async {
      await tester.enterText(field(name), text);
      tester
          .widget<TextField>(
            find.descendant(of: field(name), matching: find.byType(TextField)),
          )
          .onSubmitted!(text);
      await tester.pump();
    }

    Future<void> undo() async {
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
    }

    SwitchListTile toggle(String title) => tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, title),
    );
    T? dropdown<T>(String key) => tester
        .widget<DropdownButton<T>>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(DropdownButton<T>),
          ),
        )
        .value;

    await select('a');
    expect(value('text'), 'Kanke, Ranchi');
    await select('b');
    expect(value('text'), b.data['text']);
    for (final entry in {
      'x': '7.00',
      'y': '18.00',
      'width': '50.00',
      'height': '12.00',
      'rotation': '15.00',
      'font-size-(mm)': '4.00',
      'text-colour-(hex)': '#445566',
    }.entries) {
      expect(value(entry.key), entry.value);
    }
    expect(dropdown<int>('font-weight-b'), 700);
    expect(dropdown<String>('alignment-b'), 'right');
    expect(toggle('Locked').value, true);
    expect(toggle('Visible').value, false);
    toggle('Visible').onChanged!(true);
    await tester.pump();
    toggle('Locked').onChanged!(false);
    await tester.pump();
    expect(find.byKey(const Key('design-element-b')), findsOneWidget);
    expect(find.byKey(const Key('resize-b')), findsOneWidget);

    // Two callbacks from one build must compose, including geometry/style edits.
    final textCallback = tester.widget<TextFormField>(field('text')).onChanged!;
    final xCallback = tester
        .widget<TextField>(
          find.descendant(of: field('x'), matching: find.byType(TextField)),
        )
        .onSubmitted!;
    textCallback('Updated title');
    xCallback('9');
    await tester.pump();
    expect(live().data['text'], 'Updated title');
    expect(live().x, 9);
    expect(value('text'), 'Updated title');
    for (final entry in {
      'y': '20',
      'width': '45',
      'height': '14',
      'rotation': '30',
      'font-size-(mm)': '5',
    }.entries) {
      await submit(entry.key, entry.value);
    }
    await tester.enterText(field('text-colour-(hex)'), '#ABCDEF');
    await tester.pump();
    for (final entry in {
      'font-weight-b': 900,
      'alignment-b': 'center',
    }.entries) {
      final finder = find.descendant(
        of: find.byKey(ValueKey(entry.key)),
        matching: entry.value is int
            ? find.byType(DropdownButtonFormField<int>)
            : find.byType(DropdownButtonFormField<String>),
      );
      if (entry.value is int) {
        tester.widget<DropdownButtonFormField<int>>(finder).onChanged!(
          entry.value as int,
        );
      } else {
        tester.widget<DropdownButtonFormField<String>>(finder).onChanged!(
          entry.value as String,
        );
      }
      await tester.pump();
    }
    final rendered = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('design-element-b')),
        matching: find.text('Updated title'),
      ),
    );
    expect(rendered.style!.fontSize, 5 * 3.78);
    expect(rendered.style!.fontWeight, FontWeight.w900);
    expect(rendered.style!.color, const Color(0xffabcdef));
    expect(rendered.textAlign, TextAlign.center);
    expect(live().rotation, 30);
    await undo();
    expect(dropdown<String>('alignment-b'), 'right');
    await undo();
    expect(dropdown<int>('font-weight-b'), 700);
    await undo();
    expect(value('text-colour-(hex)'), '#445566');

    await submit('rotation', '0');
    final box = find.byKey(const Key('design-element-b'));
    final child = find.descendant(
      of: box,
      matching: find.text('Updated title'),
    );
    final beforeBox = tester.getRect(box);
    final beforeChild = tester.getRect(child);
    view().onMove!('b', 2, 3);
    await tester.pump();
    expect(value('x'), '11.00');
    expect(value('y'), '23.00');
    final delta = tester.getRect(box).topLeft - beforeBox.topLeft;
    expect(
      (tester.getRect(child).topLeft - beforeChild.topLeft - delta).distance,
      lessThan(.001),
    );
    view().onResize!('b', 2, 2);
    await tester.pump();
    expect(value('width'), '47.00');
    expect(value('height'), '16.00');
    final contentTransform = find
        .descendant(of: box, matching: find.byType(Transform))
        .first;
    expect(
      tester.getSize(contentTransform).width,
      closeTo(tester.getSize(box).width, .001),
    );
    expect(
      tester.getSize(contentTransform).height,
      closeTo(tester.getSize(box).height, .001),
    );
    await undo();
    expect(value('width'), '45.00');
    final xBeforeDrag = live().x;
    final moveGesture = await tester.startGesture(tester.getCenter(box));
    await moveGesture.moveBy(const Offset(40, 30));
    await tester.pump();
    await moveGesture.moveBy(const Offset(30, 20));
    await tester.pump();
    await moveGesture.up();
    await tester.pump();
    expect(live().x, greaterThan(xBeforeDrag));
    expect(value('x'), live().x.toStringAsFixed(2));
    expect(value('y'), live().y.toStringAsFixed(2));
    final widthBeforeDrag = live().width;
    final resizeGesture = await tester.startGesture(
      tester.getTopLeft(find.byKey(const Key('resize-b'))) + const Offset(2, 2),
    );
    await resizeGesture.moveBy(const Offset(40, 30));
    await tester.pump();
    await resizeGesture.moveBy(const Offset(30, 20));
    await tester.pump();
    await resizeGesture.up();
    await tester.pump();
    expect(live().width, greaterThan(widthBeforeDrag));
    expect(value('width'), live().width.toStringAsFixed(2));
    expect(value('height'), live().height.toStringAsFixed(2));
    await submit('x', 'NaN');
    expect(value('x'), live().x.toStringAsFixed(2));
    await select('a');
    expect(value('text'), 'Kanke, Ranchi');
    expect(value('x'), '2.00');
    expect(value('font-size-(mm)'), '3.00');
    expect(dropdown<int>('font-weight-a'), 400);
    expect(dropdown<String>('alignment-a'), 'left');
    expect(tester.takeException(), isNull);
  });
}
