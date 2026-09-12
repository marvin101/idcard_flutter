import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/providers/display_scale_provider.dart';
import 'package:idcard_flutter/widgets/app_scale_viewport.dart';
import 'package:provider/provider.dart';

const _globalTarget = Key('global-zoom-target');

Future<void> _pumpViewport(
  WidgetTester tester,
  DisplayScaleProvider displayScale, {
  Widget child = const ColoredBox(key: _globalTarget, color: Colors.white),
}) => tester.pumpWidget(
  ChangeNotifierProvider.value(
    value: displayScale,
    child: MaterialApp(
      home: Scaffold(body: AppScaleViewport(child: child)),
    ),
  ),
);

Future<void> _trackpadScale(
  WidgetTester tester,
  Offset position,
  double scale,
) async {
  final gesture = await tester.createGesture(
    pointer: 31,
    kind: PointerDeviceKind.trackpad,
  );
  await gesture.panZoomStart(position);
  await gesture.panZoomUpdate(position, scale: scale);
  await gesture.panZoomEnd();
  await tester.pump();
}

Future<void> _webPointerScale(
  WidgetTester tester,
  Offset position,
  double scale,
) async {
  tester.binding.handlePointerEvent(
    PointerScaleEvent(
      kind: PointerDeviceKind.trackpad,
      position: position,
      scale: scale,
    ),
  );
  await tester.pump();
}

Future<void> _touchPinch(
  WidgetTester tester, {
  required Offset firstStart,
  required Offset secondStart,
  required Offset firstEnd,
  required Offset secondEnd,
}) async {
  final first = await tester.createGesture(
    pointer: 41,
    kind: PointerDeviceKind.touch,
  );
  final second = await tester.createGesture(
    pointer: 42,
    kind: PointerDeviceKind.touch,
  );
  await first.down(firstStart);
  await second.down(secondStart);
  await first.moveTo(firstEnd);
  await second.moveTo(secondEnd);
  await tester.pump();
  await first.up();
  await second.up();
}

Future<void> _doubleTap(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(target);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _shortcut(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(modifier);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

void main() {
  testWidgets(
    'real trackpad pan-zoom scales from gesture start without drift',
    (tester) async {
      final displayScale = DisplayScaleProvider();
      await _pumpViewport(tester, displayScale);
      final center = tester.getCenter(find.byKey(_globalTarget));
      final gesture = await tester.createGesture(
        pointer: 31,
        kind: PointerDeviceKind.trackpad,
      );

      await gesture.panZoomStart(center);
      await gesture.panZoomUpdate(center, scale: 1.1);
      await gesture.panZoomUpdate(center, scale: 1.25);
      await gesture.panZoomEnd();
      await tester.pump();

      expect(displayScale.scale, 1.25);
    },
  );

  testWidgets('trackpad pinch zooms both ways and clamps to provider bounds', (
    tester,
  ) async {
    final displayScale = DisplayScaleProvider();
    await _pumpViewport(tester, displayScale);
    final center = tester.getCenter(find.byKey(_globalTarget));

    await _trackpadScale(tester, center, 3);
    expect(displayScale.scale, DisplayScaleProvider.maxScale);
    await _trackpadScale(tester, center, 0.1);
    expect(displayScale.scale, DisplayScaleProvider.minScale);
  });

  testWidgets('web pointer-scale signals compose and clamp through provider', (
    tester,
  ) async {
    final displayScale = DisplayScaleProvider();
    await _pumpViewport(tester, displayScale);
    final center = tester.getCenter(find.byKey(_globalTarget));

    await _webPointerScale(tester, center, 1.1);
    expect(displayScale.scale, closeTo(1.1, 0.001));
    await _webPointerScale(tester, center, 1.25);
    expect(displayScale.scale, closeTo(1.375, 0.001));
    await _webPointerScale(tester, center, 10);
    expect(displayScale.scale, DisplayScaleProvider.maxScale);
    await _webPointerScale(tester, center, 0.1);
    expect(displayScale.scale, DisplayScaleProvider.minScale);
  });

  testWidgets('real two-touch pinch zooms out and in', (tester) async {
    final displayScale = DisplayScaleProvider();
    await _pumpViewport(tester, displayScale);

    await _touchPinch(
      tester,
      firstStart: const Offset(300, 300),
      secondStart: const Offset(500, 300),
      firstEnd: const Offset(350, 300),
      secondEnd: const Offset(450, 300),
    );
    expect(displayScale.scale, lessThan(1));

    displayScale.reset();
    await tester.pump();
    await _touchPinch(
      tester,
      firstStart: const Offset(350, 300),
      secondStart: const Offset(450, 300),
      firstEnd: const Offset(300, 300),
      secondEnd: const Offset(500, 300),
    );
    expect(displayScale.scale, greaterThan(1));
  });

  testWidgets('a single-touch drag never changes app scale', (tester) async {
    final displayScale = DisplayScaleProvider();
    await _pumpViewport(tester, displayScale);
    final gesture = await tester.startGesture(
      const Offset(200, 200),
      pointer: 51,
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveTo(const Offset(500, 500));
    await gesture.up();
    await tester.pump();

    expect(displayScale.scale, DisplayScaleProvider.normalScale);
  });

  testWidgets('real double taps toggle between normal and named zoom scale', (
    tester,
  ) async {
    final displayScale = DisplayScaleProvider();
    await _pumpViewport(tester, displayScale);

    await _doubleTap(tester, find.byKey(_globalTarget));
    expect(displayScale.scale, DisplayScaleProvider.doubleTapScale);
    await _doubleTap(tester, find.byKey(_globalTarget));
    expect(displayScale.scale, DisplayScaleProvider.normalScale);
  });

  testWidgets('ordinary button taps remain functional and never trigger zoom', (
    tester,
  ) async {
    final displayScale = DisplayScaleProvider();
    var presses = 0;
    await _pumpViewport(
      tester,
      displayScale,
      child: Center(
        child: FilledButton(
          key: const Key('ordinary-button'),
          onPressed: () => presses += 1,
          child: const Text('Continue'),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('ordinary-button')));
    await tester.pump();
    expect(presses, 1);
    expect(displayScale.scale, DisplayScaleProvider.normalScale);

    await _doubleTap(tester, find.byKey(const Key('ordinary-button')));
    expect(presses, 3);
    expect(displayScale.scale, DisplayScaleProvider.normalScale);
  });

  testWidgets('Ctrl and Cmd shortcuts share provider steps and clamping', (
    tester,
  ) async {
    final displayScale = DisplayScaleProvider();
    await _pumpViewport(tester, displayScale);

    await _shortcut(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.equal,
    );
    expect(displayScale.scale, 1.1);
    await _shortcut(
      tester,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.equal,
      shift: true,
    );
    expect(displayScale.scale, DisplayScaleProvider.doubleTapScale);
    await _shortcut(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.minus,
    );
    expect(displayScale.scale, 1.1);
    await _shortcut(
      tester,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.digit0,
    );
    expect(displayScale.scale, DisplayScaleProvider.normalScale);

    for (var index = 0; index < 10; index++) {
      await _shortcut(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.equal,
      );
    }
    expect(displayScale.scale, DisplayScaleProvider.maxScale);
    for (var index = 0; index < 10; index++) {
      await _shortcut(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.minus,
      );
    }
    expect(displayScale.scale, DisplayScaleProvider.minScale);
  });

  testWidgets('local zoom boundary owns pinch without changing global scale', (
    tester,
  ) async {
    final displayScale = DisplayScaleProvider();
    final localTransform = TransformationController();
    addTearDown(localTransform.dispose);
    await _pumpViewport(
      tester,
      displayScale,
      child: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(key: _globalTarget, color: Colors.white),
          ),
          Center(
            child: SizedBox(
              key: const Key('local-zoom-area'),
              width: 300,
              height: 300,
              child: AppScaleGestureBoundary(
                child: InteractiveViewer(
                  transformationController: localTransform,
                  minScale: 0.5,
                  maxScale: 3,
                  child: const SizedBox(width: 500, height: 500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    final center = tester.getCenter(find.byKey(const Key('local-zoom-area')));

    await _touchPinch(
      tester,
      firstStart: center - const Offset(40, 0),
      secondStart: center + const Offset(40, 0),
      firstEnd: center - const Offset(90, 0),
      secondEnd: center + const Offset(90, 0),
    );
    await tester.pump();

    expect(localTransform.value.getMaxScaleOnAxis(), greaterThan(1));
    expect(displayScale.scale, DisplayScaleProvider.normalScale);

    await _touchPinch(
      tester,
      firstStart: const Offset(20, 40),
      secondStart: const Offset(100, 40),
      firstEnd: const Offset(10, 40),
      secondEnd: const Offset(140, 40),
    );
    expect(displayScale.scale, greaterThan(1));
  });

  testWidgets('local zoom boundary suppresses trackpad and double tap', (
    tester,
  ) async {
    final displayScale = DisplayScaleProvider();
    await _pumpViewport(
      tester,
      displayScale,
      child: const Center(
        child: SizedBox(
          key: Key('local-zoom-area'),
          width: 300,
          height: 300,
          child: AppScaleGestureBoundary(child: ColoredBox(color: Colors.blue)),
        ),
      ),
    );
    final target = find.byKey(const Key('local-zoom-area'));
    final center = tester.getCenter(target);

    await _trackpadScale(tester, center, 1.4);
    expect(displayScale.scale, DisplayScaleProvider.normalScale);
    await _doubleTap(tester, target);
    expect(displayScale.scale, DisplayScaleProvider.normalScale);
  });

  testWidgets('web pointer scale belongs to local viewer inside its boundary', (
    tester,
  ) async {
    final displayScale = DisplayScaleProvider();
    final localTransform = TransformationController();
    addTearDown(localTransform.dispose);
    await _pumpViewport(
      tester,
      displayScale,
      child: Stack(
        children: [
          const Positioned.fill(
            child: ColoredBox(key: _globalTarget, color: Colors.white),
          ),
          Center(
            child: SizedBox(
              key: const Key('local-web-scale-area'),
              width: 300,
              height: 300,
              child: AppScaleGestureBoundary(
                child: InteractiveViewer(
                  transformationController: localTransform,
                  minScale: 0.5,
                  maxScale: 3,
                  child: const SizedBox(width: 500, height: 500),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final localCenter = tester.getCenter(
      find.byKey(const Key('local-web-scale-area')),
    );
    await _webPointerScale(tester, localCenter, 1.4);
    expect(localTransform.value.getMaxScaleOnAxis(), closeTo(1.4, 0.001));
    expect(displayScale.scale, DisplayScaleProvider.normalScale);

    await _webPointerScale(tester, const Offset(20, 40), 1.2);
    expect(displayScale.scale, closeTo(1.2, 0.001));
  });
}
