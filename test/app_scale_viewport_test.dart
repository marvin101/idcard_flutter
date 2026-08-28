import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/providers/display_scale_provider.dart';
import 'package:idcard_flutter/widgets/app_scale_viewport.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('trackpad pinch updates the app display scale', (tester) async {
    final displayScale = DisplayScaleProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: displayScale,
        child: const MaterialApp(
          home: AppScaleViewport(child: ColoredBox(color: Colors.white)),
        ),
      ),
    );

    final listener = tester.widget<Listener>(
      find.byWidgetPredicate(
        (widget) => widget is Listener && widget.onPointerPanZoomUpdate != null,
      ),
    );
    listener.onPointerPanZoomStart!(const PointerPanZoomStartEvent());
    listener.onPointerPanZoomUpdate!(
      const PointerPanZoomUpdateEvent(scale: 1.25),
    );
    await tester.pump();

    expect(displayScale.scale, 1.25);
  });
}

