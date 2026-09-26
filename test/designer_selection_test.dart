import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/designer_selection.dart';

DesignElement item(String id, double x, double y, {String? anchor}) =>
    DesignElement(
      id: id,
      type: DesignElementType.rectangle,
      x: x,
      y: y,
      width: 10,
      height: 10,
      anchorParentId: anchor,
    );

void main() {
  const canvas = DesignCanvas(width: 100, height: 60);

  test('group movement preserves relative positions and bounds', () {
    final moved = translateDesignSelection(
      [item('a', 5, 5), item('b', 20, 15)],
      {'a', 'b'},
      canvas,
      -20,
      100,
    );
    expect(moved[0].x, 0);
    expect(moved[1].x - moved[0].x, 15);
    expect(moved[1].y - moved[0].y, 10);
    expect(moved[1].y + moved[1].height, 60);
  });

  test('group resize scales positions and sizes from one bounding box', () {
    final resized = resizeDesignSelection(
      [item('a', 10, 10), item('b', 30, 20)],
      {'a', 'b'},
      canvas,
      20,
      20,
    );
    expect(resized[0].x, 10);
    expect(resized[0].width, closeTo(16.6667, .001));
    expect(resized[1].x, closeTo(43.3333, .001));
    expect(resized[1].y, 30);
  });

  test('anchors move transitively without moving a selected child twice', () {
    final moved = translateDesignSelection(
      [
        item('a', 5, 5),
        item('b', 20, 5, anchor: 'a'),
        item('c', 35, 5, anchor: 'b'),
      ],
      {'a', 'b'},
      canvas,
      4,
      3,
    );
    expect(moved.map((element) => element.x), [9, 24, 39]);
    expect(moved.map((element) => element.y), [8, 8, 8]);
  });

  test('self and cyclic anchors are rejected', () {
    final elements = [item('a', 0, 0), item('b', 20, 0, anchor: 'a')];
    expect(canAnchorElement(elements, 'a', 'a'), isFalse);
    expect(canAnchorElement(elements, 'a', 'b'), isFalse);
    expect(canAnchorElement(elements, 'b', null), isTrue);
  });

  test('anchor metadata round trips and remains optional', () {
    final anchored = item('b', 20, 0, anchor: 'a');
    expect(DesignElement.fromJson(anchored.toJson()).anchorParentId, 'a');
    final legacy = Map<String, dynamic>.from(anchored.toJson())
      ..remove('anchor_parent_id');
    expect(DesignElement.fromJson(legacy).anchorParentId, isNull);
  });
}
