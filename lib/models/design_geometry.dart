import 'dart:math' as math;

import 'card_template.dart';
import 'design_element_library.dart';

enum CanvasResizeStrategy { keepPositions, scaleProportionally, fitToCanvas }

enum ElementGeometryProblem {
  nonFinite,
  invalidSize,
  startsOutsideCanvas,
  extendsOutsideCanvas,
}

enum CanvasElementAlignment {
  left,
  horizontalCenter,
  right,
  top,
  verticalCenter,
  bottom,
}

({double width, double height}) minimumElementSize(DesignElement element) {
  if (element.type == DesignElementType.barcode &&
      element.data['symbology'] == 'data_matrix') {
    return (width: 12, height: 12);
  }
  final definition = DesignElementLibrary.definition(element.type);
  return (width: definition.minimumWidth, height: definition.minimumHeight);
}

double? fixedElementAspectRatio(DesignElement element) {
  if (element.type == DesignElementType.barcode &&
      element.data['symbology'] == 'data_matrix') {
    return 1;
  }
  return DesignElementLibrary.definition(element.type).fixedAspectRatio;
}

bool _pointerKeepsAspectRatio(DesignElement element) =>
    fixedElementAspectRatio(element) != null ||
    {
      DesignElementType.studentPhoto,
      DesignElementType.schoolLogo,
      DesignElementType.principalSignature,
    }.contains(element.type);

/// Apply an exact inspector size while preserving mandatory square geometry.
DesignElement setElementSize(
  DesignElement element,
  DesignCanvas canvas, {
  double? width,
  double? height,
}) {
  final minimum = minimumElementSize(element);
  var nextWidth = width ?? element.width;
  var nextHeight = height ?? element.height;
  final ratio = fixedElementAspectRatio(element);
  if (ratio != null) {
    if (width != null && height == null) {
      nextHeight = nextWidth / ratio;
    } else if (height != null && width == null) {
      nextWidth = nextHeight * ratio;
    }
  }
  nextWidth = nextWidth.clamp(minimum.width, canvas.width - element.x);
  nextHeight = nextHeight.clamp(minimum.height, canvas.height - element.y);
  if (ratio != null) {
    final limitedWidth = math.min(nextWidth, nextHeight * ratio);
    final limitedHeight = limitedWidth / ratio;
    nextWidth = limitedWidth;
    nextHeight = limitedHeight;
  }
  return element.copyWith(width: nextWidth, height: nextHeight);
}

/// Resize from one of the eight canvas handles using physical millimetres.
DesignElement resizeElementFromHandle(
  DesignElement element,
  DesignCanvas canvas,
  String handle,
  double dx,
  double dy,
) {
  if (!dx.isFinite || !dy.isFinite || element.locked) return element;
  final left = handle.contains('left');
  final right = handle.contains('right');
  final top = handle.contains('top');
  final bottom = handle.contains('bottom');
  final originalRight = element.x + element.width;
  final originalBottom = element.y + element.height;
  var x = element.x;
  var y = element.y;
  var width = element.width;
  var height = element.height;
  if (left) {
    x += dx;
    width -= dx;
  }
  if (right) width += dx;
  if (top) {
    y += dy;
    height -= dy;
  }
  if (bottom) height += dy;
  if (_pointerKeepsAspectRatio(element)) {
    final ratio =
        fixedElementAspectRatio(element) ?? element.width / element.height;
    if (dx.abs() >= dy.abs()) {
      height = width / ratio;
    } else {
      width = height * ratio;
    }
    if (left) x = originalRight - width;
    if (top) y = originalBottom - height;
  }
  final minimum = minimumElementSize(element);
  width = width.clamp(minimum.width, canvas.width);
  height = height.clamp(minimum.height, canvas.height);
  if (left) x = originalRight - width;
  if (top) y = originalBottom - height;
  x = x.clamp(0.0, canvas.width - width);
  y = y.clamp(0.0, canvas.height - height);
  width = math.min(width, canvas.width - x);
  height = math.min(height, canvas.height - y);
  return element.copyWith(x: x, y: y, width: width, height: height);
}

DesignElement alignElementToCanvas(
  DesignElement element,
  DesignCanvas canvas,
  CanvasElementAlignment alignment,
) {
  if (element.locked) return element;
  return element.copyWith(
    x: switch (alignment) {
      CanvasElementAlignment.left => 0,
      CanvasElementAlignment.horizontalCenter =>
        (canvas.width - element.width) / 2,
      CanvasElementAlignment.right => canvas.width - element.width,
      _ => element.x,
    },
    y: switch (alignment) {
      CanvasElementAlignment.top => 0,
      CanvasElementAlignment.verticalCenter =>
        (canvas.height - element.height) / 2,
      CanvasElementAlignment.bottom => canvas.height - element.height,
      _ => element.y,
    },
  );
}

Set<ElementGeometryProblem> validateElementGeometry(
  DesignElement element,
  DesignCanvas canvas,
) {
  final values = [element.x, element.y, element.width, element.height];
  final problems = <ElementGeometryProblem>{};
  if (values.any((value) => !value.isFinite)) {
    problems.add(ElementGeometryProblem.nonFinite);
    return problems;
  }
  if (element.width <= 0 || element.height <= 0) {
    problems.add(ElementGeometryProblem.invalidSize);
  }
  if (element.x < 0 ||
      element.y < 0 ||
      element.x >= canvas.width ||
      element.y >= canvas.height) {
    problems.add(ElementGeometryProblem.startsOutsideCanvas);
  }
  if (element.x + element.width > canvas.width ||
      element.y + element.height > canvas.height) {
    problems.add(ElementGeometryProblem.extendsOutsideCanvas);
  }
  return problems;
}

bool hasElementsOutsideCanvas(DesignDocument document) => document.elements.any(
  (element) => validateElementGeometry(element, document.canvas).any(
    (problem) =>
        problem == ElementGeometryProblem.startsOutsideCanvas ||
        problem == ElementGeometryProblem.extendsOutsideCanvas,
  ),
);

DesignDocument resizeDesignDocument(
  DesignDocument document,
  DesignCanvas nextCanvas,
  CanvasResizeStrategy strategy,
) {
  final oldCanvas = document.canvas;
  final elements = switch (strategy) {
    CanvasResizeStrategy.keepPositions => document.elements,
    CanvasResizeStrategy.scaleProportionally => [
      for (final element in document.elements)
        element.copyWith(
          x: element.x * nextCanvas.width / oldCanvas.width,
          y: element.y * nextCanvas.height / oldCanvas.height,
          width: element.width * nextCanvas.width / oldCanvas.width,
          height: element.height * nextCanvas.height / oldCanvas.height,
        ),
    ],
    CanvasResizeStrategy.fitToCanvas => [
      for (final element in document.elements)
        _fitElementToCanvas(element, nextCanvas),
    ],
  };
  return document.copyWith(canvas: nextCanvas, elements: elements);
}

DesignElement _fitElementToCanvas(DesignElement element, DesignCanvas canvas) {
  final width = math.min(element.width, canvas.width);
  final height = math.min(element.height, canvas.height);
  return element.copyWith(
    x: element.x.clamp(0.0, math.max(0.0, canvas.width - width)),
    y: element.y.clamp(0.0, math.max(0.0, canvas.height - height)),
    width: width,
    height: height,
  );
}
