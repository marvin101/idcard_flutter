import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/screens/card_designer_screen.dart';
import 'package:idcard_flutter/services/api_service.dart';
import 'package:idcard_flutter/widgets/designer_guides.dart';
import 'designer_interactions_test.dart' as h;

void main() {
  test(
    'guides detect both axes, edges and centers with screen-space tolerance',
    () {
      for (final scale in [2.0, 10.0, 30.0]) {
        for (final axis in Axis.values) {
          for (var anchor = 0; anchor < 3; anchor++) {
            final target = h.elementB.copyWith(
              x: 50,
              y: 50,
              width: 90,
              height: 90,
            );
            final coordinate = 50 + anchor * 45 - anchor * 15 + 4 / scale;
            final moving = h.elementA.copyWith(
              width: 30,
              height: 30,
              x: axis == Axis.vertical ? coordinate : 0,
              y: axis == Axis.horizontal ? coordinate : 0,
            );
            final guides = DesignerGuides.detect(
              moving: moving,
              elements: [moving, target],
              pixelsPerMm: scale,
            );
            final guide = guides.singleWhere((g) => g.axis == axis);
            expect(guide.position, 50 + anchor * 45);
            expect(guide.anchor, anchor);
            final away = moving.copyWith(
              x: axis == Axis.vertical ? coordinate + 2 / scale : moving.x,
              y: axis == Axis.horizontal ? coordinate + 2 / scale : moving.y,
            );
            expect(
              DesignerGuides.detect(
                moving: away,
                elements: [target],
                pixelsPerMm: scale,
              ).where((g) => g.axis == axis),
              isEmpty,
            );
            expect(
              DesignerGuides.detect(
                moving: moving,
                elements: [moving, target.copyWith(visible: false)],
                pixelsPerMm: scale,
              ),
              isEmpty,
            );
          }
        }
      }
      final rotated = DesignerGuides.bounds(h.elementA.copyWith(rotation: 90));
      expect(rotated.width, closeTo(10, .0001));
      expect(rotated.height, closeTo(30, .0001));
    },
  );

  testWidgets(
    'guides are transient and undo terminates an active pointer transaction',
    (t) async {
      await h.mount(t);
      await h.select(t);
      final box = find.byKey(const Key('design-element-a'));
      final scale = t.getSize(box).width / 30;
      final pointer = await t.startGesture(
        t.getCenter(box),
        kind: PointerDeviceKind.mouse,
      );
      await pointer.moveBy(Offset(.1 * scale, 2 * scale));
      await t.pump();
      final guide = t.widget<DesignerGuideOverlay>(
        find.byKey(const Key('designer-smart-guides')),
      );
      expect(guide.guides.any((g) => g.axis == Axis.vertical), true);
      expect(jsonEncode(h.view(t).document.toJson()), isNot(contains('guide')));
      await h.shortcut(t, LogicalKeyboardKey.keyZ);
      expect(h.live(t).x, 10);
      expect(h.live(t).y, 10);
      expect(find.byKey(const Key('designer-smart-guides')), findsNothing);
      await pointer.moveBy(Offset(scale, scale));
      await t.pump();
      expect(h.live(t).x, 10);
      await pointer.up();
      await t.pump();
      await h.toolbar(t, 'Redo');
      expect(h.live(t).y, closeTo(12, .001));
      final next = await t.startGesture(
        t.getCenter(box),
        kind: PointerDeviceKind.mouse,
      );
      await next.moveBy(Offset(0, scale));
      await t.pump();
      expect(find.byKey(const Key('designer-smart-guides')), findsOneWidget);
      await next.up();
      await t.pump();
      expect(find.byKey(const Key('designer-smart-guides')), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('nudge duplicate delete and add restore selection in history', (
    t,
  ) async {
    await h.mount(t, snap: true);
    await h.select(t);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(h.live(t).x, closeTo(10.1, .001));
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pump();
    expect(h.live(t).y, 11);
    await h.shortcut(t, LogicalKeyboardKey.keyD);
    final copy = h.view(t).selectedId;
    expect(copy, isNot('a'));
    expect(h.view(t).document.elements.length, 3);
    await h.shortcut(t, LogicalKeyboardKey.keyZ);
    expect(h.view(t).selectedId, 'a');
    expect(h.view(t).document.elements.length, 2);
    await h.shortcut(t, LogicalKeyboardKey.keyY);
    expect(h.view(t).selectedId, copy);
    await t.sendKeyEvent(LogicalKeyboardKey.delete);
    await t.pump();
    expect(h.view(t).selectedId, isNull);
    expect(h.view(t).document.elements.length, 2);
    await h.shortcut(t, LogicalKeyboardKey.keyZ);
    expect(h.view(t).selectedId, copy);
    expect(h.value(t, 'text'), 'First');
    await h.select(t, 'b');
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.pump();
    await h.shortcut(t, LogicalKeyboardKey.keyZ);
    expect(h.view(t).selectedId, 'b');
    expect(h.value(t, 'text'), 'Second');
    for (final key in [
      'add-text',
      'add-photo',
      'add-logo',
      'add-rectangle',
      'add-line',
    ]) {
      final count = h.view(t).document.elements.length;
      await t.tap(find.byKey(Key(key)));
      await t.pump();
      final added = h.view(t).selectedId;
      expect(h.view(t).document.elements.length, count + 1);
      await h.toolbar(t, 'Undo');
      expect(h.view(t).selectedId, 'b');
      await h.toolbar(t, 'Redo');
      expect(h.view(t).selectedId, added);
      await h.toolbar(t, 'Undo');
    }
    // Command conventions share the same history actions.
    await t.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyD);
    await t.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await t.pump();
    expect(h.view(t).document.elements.length, 4);
    await t.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await t.pump();
    expect(h.view(t).selectedId, 'b');
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'typing suppresses object shortcuts and rotation steps 1 or 10 degrees',
    (t) async {
      await h.mount(t);
      await h.select(t);
      for (final target in [
        h.field('text'),
        h.field('x'),
        find.byKey(const Key('template-name')),
      ]) {
        await t.tap(target);
        await t.pump();
        await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await t.sendKeyEvent(LogicalKeyboardKey.delete);
        await t.sendKeyEvent(LogicalKeyboardKey.backspace);
        await h.shortcut(t, LogicalKeyboardKey.keyD);
        expect(h.view(t).document.elements.length, 2);
        expect(h.live(t).x, 10);
      }
      await t.tap(h.field('rotation'));
      await t.pump();
      await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await t.pump();
      expect(h.live(t).rotation, 1);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await t.pump();
      expect(h.live(t).rotation, -9);
      await t.sendEventToBinding(
        PointerScrollEvent(
          kind: PointerDeviceKind.mouse,
          position: t.getCenter(h.field('rotation')),
          scrollDelta: const Offset(0, -20),
        ),
      );
      await t.pump();
      expect(h.live(t).rotation, -8);
      await h.submit(t, 'width', '-30');
      expect(h.live(t).width, 2);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'palette, custom alpha HEX, recent colours and history preserve live colour',
    (t) async {
      await h.mount(t);
      await h.select(t);
      final choose = find.byKey(const Key('choose-property-text-colour-(hex)'));
      await t.tap(choose);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('palette-#F44336')));
      await t.pump();
      expect(h.live(t).style['color'], '#112233');
      await t.tap(find.byKey(const Key('colour-apply')));
      await t.pumpAndSettle();
      expect(h.live(t).style['color'], '#F44336');
      await h.toolbar(t, 'Undo');
      expect(h.value(t, 'text-colour-(hex)'), '#112233');
      expect(h.enabled(t, 'Undo'), false);
      await h.toolbar(t, 'Redo');
      await t.enterText(h.field('text-colour-(hex)'), 'invalid');
      await t.pump();
      expect(h.live(t).style['color'], '#F44336');
      await t.enterText(h.field('text-colour-(hex)'), '#801234ab');
      await t.pump();
      expect(h.live(t).style['color'], '#801234AB');
      await t.tap(choose);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('recent-#F44336')), findsOneWidget);
      await t.enterText(find.byKey(const Key('colour-custom-hex')), '#BAD');
      await t.pump();
      expect(
        t.widget<FilledButton>(find.byKey(const Key('colour-apply'))).onPressed,
        isNull,
      );
      await t.enterText(
        find.byKey(const Key('colour-custom-hex')),
        '#40223344',
      );
      await t.pump();
      await t.tap(find.byKey(const Key('colour-apply')));
      await t.pumpAndSettle();
      expect(h.live(t).style['color'], '#40223344');
      await h.toolbar(t, 'Undo');
      expect(h.live(t).style['color'], '#801234AB');
      await h.select(t, 'b');
      expect(h.value(t, 'text-colour-(hex)'), '#111111');
      await h.select(t);
      expect(h.value(t, 'text-colour-(hex)'), '#801234AB');
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('save shortcut persists the live document while editing text', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(1600, 1800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final saved = <Map<String, dynamic>>[];
    final api = ApiService(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        if (request.method == 'PUT') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          saved.add(body);
          return http.Response(jsonEncode(body), 200);
        }
        return http.Response('[]', 404);
      }),
    );
    addTearDown(api.dispose);
    await t.pumpWidget(
      MaterialApp(
        home: CardDesignerScreen(
          schoolUuid: 'school',
          api: api,
          initialTemplate: CardTemplate(
            name: 'Test',
            document: DesignDocument(
              canvas: const DesignCanvas(width: 100, height: 80),
              elements: const [h.elementA],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await h.select(t);
    await t.enterText(h.field('text'), 'Saved text');
    await t.pump();
    await h.shortcut(t, LogicalKeyboardKey.keyS);
    await t.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(jsonEncode(saved.single), contains('Saved text'));
    expect(find.text('Saved'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
