import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/screens/card_designer_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/design_document_view.dart';

const elementA = DesignElement(
  id: 'a',
  type: DesignElementType.text,
  x: 10,
  y: 10,
  width: 30,
  height: 10,
  data: {'text': 'First'},
  style: {
    'font_size': 3.0,
    'font_weight': 400,
    'alignment': 'left',
    'color': '#112233',
  },
);
const elementB = DesignElement(
  id: 'b',
  type: DesignElementType.text,
  x: 10,
  y: 40,
  width: 30,
  height: 10,
  data: {'text': 'Second'},
);

Future<void> mount(
  WidgetTester tester, {
  Size size = const Size(1600, 1800),
  bool snap = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final api = ApiService(
    baseUrl: 'http://test',
    client: MockClient(
      (r) async => http.Response(
        r.url.path.endsWith('/student-fields') ? '[]' : '{}',
        r.url.path.endsWith('/student-fields') ? 200 : 404,
      ),
    ),
  );
  addTearDown(api.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: CardDesignerScreen(
        schoolUuid: 'school',
        api: api,
        initialTemplate: CardTemplate(
          name: 'Test',
          document: DesignDocument(
            canvas: const DesignCanvas(width: 100, height: 80),
            elements: const [elementA, elementB],
            settings: {
              'snap_enabled': snap,
              'grid_enabled': snap,
              'grid_size': 2.0,
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DesignDocumentView view(WidgetTester t) =>
    t.widget<DesignDocumentView>(find.byKey(const Key('designer-canvas')));
DesignElement live(WidgetTester t, [String id = 'a']) =>
    view(t).document.elements.firstWhere((e) => e.id == id);
Finder field(String name) => find.byKey(Key('property-$name'));
String value(WidgetTester t, String name) =>
    t.widget<TextFormField>(field(name)).controller!.text;
bool enabled(WidgetTester t, String tooltip) =>
    t
        .widget<IconButton>(
          find.byWidgetPredicate(
            (w) => w is IconButton && w.tooltip == tooltip,
          ),
        )
        .onPressed !=
    null;
Future<void> select(WidgetTester t, [String id = 'a']) async {
  view(t).onSelect!(id);
  await t.pump();
}

Future<void> toolbar(WidgetTester t, String name) async {
  await t.tap(find.byTooltip(name));
  await t.pump();
}

Future<void> submit(WidgetTester t, String name, String text) async {
  await t.enterText(field(name), text);
  t
      .widget<TextField>(
        find.descendant(of: field(name), matching: find.byType(TextField)),
      )
      .onSubmitted!(text);
  await t.pump();
}

Future<void> shortcut(
  WidgetTester t,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await t.sendKeyEvent(key);
  if (shift) await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pump();
}

void main() {
  testWidgets(
    'all property mutations restore model and Properties through history',
    (t) async {
      await mount(t);
      await select(t);
      expect(enabled(t, 'Undo'), false);
      expect(enabled(t, 'Redo'), false);
      for (final entry in {
        'x': '12',
        'y': '13',
        'width': '32',
        'height': '12',
        'rotation': '25',
        'font-size-(mm)': '4',
      }.entries) {
        final before = value(t, entry.key);
        await submit(t, entry.key, entry.value);
        final after = value(t, entry.key);
        expect(after, isNot(before));
        await shortcut(t, LogicalKeyboardKey.keyZ);
        expect(value(t, entry.key), before);
        expect(enabled(t, 'Redo'), true);
        await shortcut(t, LogicalKeyboardKey.keyY);
        expect(value(t, entry.key), after);
      }
      await t.enterText(field('text'), 'Changed');
      await t.pump();
      await shortcut(t, LogicalKeyboardKey.keyZ);
      expect(value(t, 'text'), 'First');
      expect(live(t).data['text'], 'First');
      await shortcut(t, LogicalKeyboardKey.keyZ, shift: true);
      expect(value(t, 'text'), 'Changed');
      await t.enterText(field('text-colour-(hex)'), '#ABCDEF');
      await t.pump();
      await toolbar(t, 'Undo');
      expect(value(t, 'text-colour-(hex)'), '#112233');
      await toolbar(t, 'Redo');
      expect(live(t).style['color'], '#ABCDEF');
      for (final label in ['Locked', 'Visible']) {
        SwitchListTile toggle() => t.widget<SwitchListTile>(
          find.widgetWithText(SwitchListTile, label),
        );
        final before = toggle().value;
        toggle().onChanged!(!before);
        await t.pump();
        await toolbar(t, 'Undo');
        expect(toggle().value, before);
        await toolbar(t, 'Redo');
        expect(toggle().value, !before);
        await toolbar(t, 'Undo');
      }
      for (final name in ['font-weight-a', 'alignment-a']) {
        final isWeight = name.startsWith('font');
        final scope = find.byKey(ValueKey(name));
        if (isWeight) {
          t
              .widget<DropdownButtonFormField<int>>(
                find.descendant(
                  of: scope,
                  matching: find.byType(DropdownButtonFormField<int>),
                ),
              )
              .onChanged!(700);
        } else {
          t
              .widget<DropdownButtonFormField<String>>(
                find.descendant(
                  of: scope,
                  matching: find.byType(DropdownButtonFormField<String>),
                ),
              )
              .onChanged!('right');
        }
        await t.pump();
        await toolbar(t, 'Undo');
        expect(
          live(t).style[isWeight ? 'font_weight' : 'alignment'],
          isWeight ? 400 : 'left',
        );
        await toolbar(t, 'Redo');
        expect(
          live(t).style[isWeight ? 'font_weight' : 'alignment'],
          isWeight ? 700 : 'right',
        );
      }
      await t.enterText(find.byKey(const Key('template-name')), 'Renamed');
      await t.pump();
      await shortcut(t, LogicalKeyboardKey.keyZ);
      expect(
        t
            .widget<TextField>(find.byKey(const Key('template-name')))
            .controller!
            .text,
        'Test',
      );
      await shortcut(t, LogicalKeyboardKey.keyY);
      expect(
        t
            .widget<TextField>(find.byKey(const Key('template-name')))
            .controller!
            .text,
        'Renamed',
      );
      await toolbar(t, 'Undo');
      await submit(t, 'x', '14');
      expect(enabled(t, 'Redo'), false);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'mouse movement and resize each create exactly one transaction at zoom',
    (t) async {
      await mount(t);
      await select(t);
      t.widget<Slider>(find.byType(Slider)).onChanged!(1.5);
      await t.pump();
      // Exercise the second zoom transform as well as the designer zoom slider.
      t
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!
          .value = Matrix4.identity()
        ..scaleByDouble(1.1, 1.1, 1.1, 1);
      await t.pump();
      final box = find.byKey(const Key('design-element-a'));
      final scale =
          (t.getTopRight(box) - t.getTopLeft(box)).distance / live(t).width;
      final start = t.getRect(box).center;
      final pointer = await t.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await pointer.moveBy(Offset(scale * .3, scale * .2));
      await t.pump();
      expect(live(t).x, closeTo(10.3, .001));
      expect(value(t, 'x'), '10.30');
      expect(value(t, 'y'), '10.20');
      final toolbarBefore = t.widget<Material>(
        find
            .ancestor(
              of: find.byKey(const Key('add-text')),
              matching: find.byType(Material),
            )
            .first,
      );
      final layerBefore = t.widget<ListTile>(find.byKey(const Key('layer-a')));
      for (var i = 0; i < 5; i++) {
        await pointer.moveBy(Offset(scale * .3, scale * .2));
        await t.pump();
      }
      expect(
        identical(
          layerBefore,
          t.widget<ListTile>(find.byKey(const Key('layer-a'))),
        ),
        true,
      );
      expect(
        identical(
          toolbarBefore,
          t.widget<Material>(
            find
                .ancestor(
                  of: find.byKey(const Key('add-text')),
                  matching: find.byType(Material),
                )
                .first,
          ),
        ),
        true,
      );
      await pointer.up();
      await t.pump();
      expect(live(t).x, closeTo(11.8, .001));
      await toolbar(t, 'Undo');
      expect(live(t).x, 10);
      expect(live(t).y, 10);
      expect(value(t, 'x'), '10.00');
      expect(enabled(t, 'Undo'), false);
      await toolbar(t, 'Redo');
      expect(live(t).x, closeTo(11.8, .001));
      final resize = await t.startGesture(
        t.getTopLeft(find.byKey(const Key('resize-a'))) + const Offset(2, 2),
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 4; i++) {
        await resize.moveBy(Offset(scale * .5, scale * .25));
        await t.pump();
      }
      await resize.up();
      await t.pump();
      expect(live(t).width, closeTo(32, .001));
      expect(live(t).height, closeTo(11, .001));
      await toolbar(t, 'Undo');
      expect(value(t, 'width'), '30.00');
      expect(value(t, 'height'), '10.00');
      await toolbar(t, 'Undo');
      expect(live(t).x, 10);
      expect(enabled(t, 'Undo'), false);
      await toolbar(t, 'Redo');
      await toolbar(t, 'Redo');
      expect(value(t, 'width'), '32.00');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'snapping accumulates small deltas and clamps at the canvas edge',
    (t) async {
      await mount(t, snap: true);
      await select(t);
      final box = find.byKey(const Key('design-element-a'));
      final scale =
          (t.getTopRight(box) - t.getTopLeft(box)).distance / live(t).width;
      final pointer = await t.startGesture(
        t.getCenter(box),
        kind: PointerDeviceKind.mouse,
      );
      for (var i = 0; i < 7; i++) {
        await pointer.moveBy(Offset(scale * .2, 0));
        await t.pump();
      }
      expect(live(t).x, 12);
      expect(value(t, 'x'), '12.00');
      await pointer.moveBy(Offset(scale * 200, 0));
      await t.pump();
      expect(live(t).x, 70);
      await pointer.up();
      await t.pump();
      await toolbar(t, 'Undo');
      expect(live(t).x, 10);
      expect(enabled(t, 'Undo'), false);
      await toolbar(t, 'Redo');
      expect(live(t).x, 70);
    },
  );

  testWidgets(
    'numeric arrows and wheel step immediately without scrolling Properties',
    (t) async {
      await mount(t, size: const Size(1600, 900));
      await select(t);
      await t.tap(field('x'));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.pump();
      expect(live(t).x, closeTo(10.1, .001));
      expect(value(t, 'x'), '10.10');
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pump();
      expect(live(t).x, closeTo(9.1, .001));
      final beforePosition = t.getTopLeft(field('x'));
      expect(
        Scrollable.of(t.element(field('x'))).position.maxScrollExtent,
        greaterThan(0),
      );
      await t.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: t.getCenter(field('x')),
          scrollDelta: const Offset(0, -20),
        ),
      );
      await t.pump();
      expect(live(t).x, closeTo(9.2, .001));
      expect(t.getTopLeft(field('x')), beforePosition);
      // Hovered, unfocused numbers also step, while the focused text is untouched.
      await t.tap(field('text'));
      await t.pump();
      await t.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: t.getCenter(field('width')),
          scrollDelta: const Offset(0, 20),
        ),
      );
      await t.pump();
      expect(live(t).width, closeTo(29.9, .001));
      expect(t.getTopLeft(field('x')), beforePosition);
      await shortcut(t, LogicalKeyboardKey.keyZ);
      expect(value(t, 'width'), '30.00');
      await submit(t, 'x', '-100');
      expect(live(t).x, 0);
      await submit(t, 'x', 'Infinity');
      expect(value(t, 'x'), '0.00');
      await submit(t, 'x', 'NaN');
      expect(value(t, 'x'), '0.00');
      await submit(t, 'rotation', '900');
      expect(live(t).rotation, 360);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'selection updates on mouse down after repeated switching without history',
    (t) async {
      await mount(t);
      for (var i = 0; i < 12; i++) {
        final id = i.isEven ? 'a' : 'b';
        final pointer = await t.startGesture(
          t.getCenter(find.byKey(Key('design-element-$id'))),
          kind: PointerDeviceKind.mouse,
        );
        await t.pump();
        expect(view(t).selectedId, id);
        expect(value(t, 'text'), id == 'a' ? 'First' : 'Second');
        await pointer.up();
        await t.pump();
      }
      expect(enabled(t, 'Undo'), false);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'small screens warn, continue once, and mobile uses an information state',
    (t) async {
      await mount(t, size: const Size(900, 700));
      expect(find.byKey(const Key('designer-screen-warning')), findsOneWidget);
      expect(find.byKey(const Key('designer-canvas')), findsNothing);
      await t.tap(find.text('Continue anyway'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('designer-canvas')), findsOneWidget);
      await select(t);
      expect(find.byKey(const Key('designer-screen-warning')), findsNothing);
      await t.binding.setSurfaceSize(const Size(390, 844));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('designer-screen-warning')), findsOneWidget);
      expect(find.text('Continue anyway'), findsNothing);
      expect(find.byKey(const Key('designer-canvas')), findsNothing);
      await t.binding.setSurfaceSize(const Size(1200, 800));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('designer-canvas')), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
