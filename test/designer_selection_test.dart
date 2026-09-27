import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/designer_selection.dart';
import 'package:idcard_flutter/models/design_geometry.dart';

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

  group('alignment anchors', () {
    const parent = DesignElement(
      id: 'parent',
      type: DesignElementType.rectangle,
      x: 20,
      y: 10,
      width: 40,
      height: 30,
    );
    const child = DesignElement(
      id: 'child',
      type: DesignElementType.rectangle,
      x: 0,
      y: 0,
      width: 10,
      height: 6,
    );

    test('left, center, right, top, middle and bottom points coincide', () {
      for (final alignment in DesignAnchorAlignment.values) {
        final aligned = alignElementToParent(
          child,
          parent,
          alignment,
          offsetX: 0,
          offsetY: 0,
        );
        final parentX = parent.x + parent.width * alignment.xFactor;
        final childX = aligned.x + aligned.width * alignment.xFactor;
        final parentY = parent.y + parent.height * alignment.yFactor;
        final childY = aligned.y + aligned.height * alignment.yFactor;
        expect((childX - parentX).abs(), lessThan(.000001));
        expect((childY - parentY).abs(), lessThan(.000001));
      }
    });

    test('top-left is a combined corner anchor', () {
      final aligned = alignElementToParent(
        child,
        parent,
        DesignAnchorAlignment.topLeft,
        offsetX: 0,
        offsetY: 0,
      );
      expect(aligned.x, parent.x);
      expect(aligned.y, parent.y);
    });

    test('parent movement and resize recompute configured anchors', () {
      final anchored = alignElementToParent(
        child,
        parent,
        DesignAnchorAlignment.bottomRight,
        offsetX: 0,
        offsetY: 0,
      );
      final moved = translateDesignSelection(
        [parent, anchored],
        {'parent'},
        const DesignCanvas(width: 120, height: 80),
        7,
        4,
      );
      final movedParent = moved[0];
      final movedChild = moved[1];
      expect(
        movedChild.x + movedChild.width,
        movedParent.x + movedParent.width,
      );
      expect(
        movedChild.y + movedChild.height,
        movedParent.y + movedParent.height,
      );

      final resized = resolveDesignAnchors([
        movedParent.copyWith(width: 55, height: 42),
        movedChild,
      ]);
      expect(resized[1].x + resized[1].width, resized[0].x + 55);
      expect(resized[1].y + resized[1].height, resized[0].y + 42);
    });

    test('child resize retains its selected anchor point', () {
      final anchored = alignElementToParent(
        child,
        parent,
        DesignAnchorAlignment.center,
        offsetX: 0,
        offsetY: 0,
      );
      final resized = resolveDesignAnchors([
        parent,
        anchored.copyWith(width: 18, height: 12),
      ])[1];
      expect(resized.x + resized.width / 2, parent.x + parent.width / 2);
      expect(resized.y + resized.height / 2, parent.y + parent.height / 2);
    });

    test('manual child movement persists as an anchor offset', () {
      final anchored = alignElementToParent(
        child,
        parent,
        DesignAnchorAlignment.center,
        offsetX: 0,
        offsetY: 0,
      );
      final moved = translateDesignSelection(
        [parent, anchored],
        {'child'},
        const DesignCanvas(width: 120, height: 80),
        3,
        -2,
      )[1];
      expect(moved.anchorOffsetX, 3);
      expect(moved.anchorOffsetY, -2);
      expect(moved.x + moved.width / 2, parent.x + parent.width / 2 + 3);
      expect(moved.y + moved.height / 2, parent.y + parent.height / 2 - 2);
    });

    test('selecting an ancestor and descendant does not double-offset it', () {
      final middle = alignElementToParent(
        child.copyWith(id: 'middle'),
        parent,
        DesignAnchorAlignment.center,
        offsetX: 0,
        offsetY: 0,
      );
      final leaf = alignElementToParent(
        child.copyWith(id: 'leaf'),
        middle,
        DesignAnchorAlignment.center,
        offsetX: 2,
        offsetY: 1,
      );
      final moved = translateDesignSelection(
        [parent, middle, leaf],
        {'parent', 'leaf'},
        const DesignCanvas(width: 120, height: 80),
        4,
        3,
      );
      expect(moved[2].anchorOffsetX, 2);
      expect(moved[2].anchorOffsetY, 1);
      expect(moved[2].x, leaf.x + 4);
      expect(moved[2].y, leaf.y + 3);
    });

    test('configured anchor geometry survives save and reload', () {
      final anchored = alignElementToParent(
        child,
        parent,
        DesignAnchorAlignment.topCenter,
        offsetX: 1.25,
        offsetY: -0.5,
      );
      final document = DesignDocument(
        canvas: const DesignCanvas(width: 100, height: 60),
        elements: [parent, anchored],
      );
      final reloaded = DesignDocument.fromJson(document.toJson());
      final resolved = resolveDesignAnchors(reloaded.elements);
      expect(resolved[1].anchorAlignment, 'top_center');
      expect(resolved[1].anchorOffsetX, 1.25);
      expect(resolved[1].anchorOffsetY, -0.5);
      expect(resolved[1].x + resolved[1].width / 2, 41.25);
      expect(resolved[1].y, 9.5);
    });

    test('legacy ID-only anchors keep their saved geometry', () {
      final legacy = child.copyWith(x: 73, y: 42, anchorParentId: parent.id);
      final resolved = resolveDesignAnchors([parent, legacy]);
      expect(resolved[1].x, 73);
      expect(resolved[1].y, 42);
      expect(resolved[1].anchorAlignment, isNull);
    });
  });
}
