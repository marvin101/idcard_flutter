// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math' as math;

import 'card_template.dart';

class DesignSelectionBounds {
  const DesignSelectionBounds(this.left, this.top, this.right, this.bottom);
  final double left, top, right, bottom;
  double get width => right - left;
  double get height => bottom - top;
}

DesignSelectionBounds? designSelectionBounds(
  Iterable<DesignElement> elements,
  Set<String> ids,
) {
  final selected = elements.where((item) => ids.contains(item.id)).toList();
  if (selected.isEmpty) return null;
  return DesignSelectionBounds(
    selected.map((item) => item.x).reduce(math.min),
    selected.map((item) => item.y).reduce(math.min),
    selected.map((item) => item.x + item.width).reduce(math.max),
    selected.map((item) => item.y + item.height).reduce(math.max),
  );
}

bool canAnchorElement(
  List<DesignElement> elements,
  String childId,
  String? parentId,
) {
  if (parentId == null) return true;
  if (childId == parentId) return false;
  final byId = {for (final item in elements) item.id: item};
  String? current = parentId;
  final visited = <String>{};
  while (current != null && visited.add(current)) {
    if (current == childId) return false;
    current = byId[current]?.anchorParentId;
  }
  return current == null;
}

Set<String> anchoredClosure(List<DesignElement> elements, Set<String> roots) {
  final result = <String>{...roots};
  var changed = true;
  while (changed) {
    changed = false;
    for (final item in elements) {
      if (item.anchorParentId != null &&
          result.contains(item.anchorParentId) &&
          result.add(item.id)) {
        changed = true;
      }
    }
  }
  return result;
}

List<DesignElement> translateDesignSelection(
  List<DesignElement> elements,
  Set<String> selectedIds,
  DesignCanvas canvas,
  double dx,
  double dy,
) {
  final moving = anchoredClosure(elements, selectedIds);
  final bounds = designSelectionBounds(elements, moving);
  if (bounds == null) return elements;
  final boundedDx = dx
      .clamp(-bounds.left, canvas.width - bounds.right)
      .toDouble();
  final boundedDy = dy
      .clamp(-bounds.top, canvas.height - bounds.bottom)
      .toDouble();
  return [
    for (final item in elements)
      if (moving.contains(item.id) && !item.locked)
        item.copyWith(x: item.x + boundedDx, y: item.y + boundedDy)
      else
        item,
  ];
}

List<DesignElement> resizeDesignSelection(
  List<DesignElement> elements,
  Set<String> selectedIds,
  DesignCanvas canvas,
  double dw,
  double dh,
) {
  final bounds = designSelectionBounds(elements, selectedIds);
  if (bounds == null || bounds.width <= 0 || bounds.height <= 0)
    return elements;
  final nextWidth = (bounds.width + dw)
      .clamp(0.5, canvas.width - bounds.left)
      .toDouble();
  final nextHeight = (bounds.height + dh)
      .clamp(0.5, canvas.height - bounds.top)
      .toDouble();
  final sx = nextWidth / bounds.width;
  final sy = nextHeight / bounds.height;
  return [
    for (final item in elements)
      if (selectedIds.contains(item.id) && !item.locked)
        item.copyWith(
          x: bounds.left + (item.x - bounds.left) * sx,
          y: bounds.top + (item.y - bounds.top) * sy,
          width: math.max(0.5, item.width * sx),
          height: math.max(0.5, item.height * sy),
        )
      else
        item,
  ];
}
