import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/providers/display_scale_provider.dart';

void main() {
  test('display scale supports bounded zoom and reset', () {
    final displayScale = DisplayScaleProvider();
    expect(displayScale.scale, 1);

    displayScale.zoomIn();
    expect(displayScale.scale, 1.1);
    expect(displayScale.percentage, 110);

    displayScale.zoomOut();
    expect(displayScale.scale, 1);

    displayScale.zoomOut();
    displayScale.reset();
    expect(displayScale.scale, 1);

    for (var index = 0; index < 10; index++) {
      displayScale.zoomIn();
    }
    expect(displayScale.scale, 1.5);
    expect(displayScale.canZoomIn, isFalse);

    for (var index = 0; index < 10; index++) {
      displayScale.zoomOut();
    }
    expect(displayScale.scale, 0.75);
    expect(displayScale.canZoomOut, isFalse);
  });

  test('pinch scaling is continuous and remains bounded', () {
    final displayScale = DisplayScaleProvider();

    displayScale.setScale(1.23);
    expect(displayScale.scale, 1.23);
    expect(displayScale.percentage, 123);

    displayScale.setScale(4);
    expect(displayScale.scale, DisplayScaleProvider.maxScale);

    displayScale.setScale(0.1);
    expect(displayScale.scale, DisplayScaleProvider.minScale);
  });
}

