import 'dart:math' as math;

import 'card_template.dart';

enum CanvasResizeStrategy { keepPositions, scaleProportionally, fitToCanvas }

enum ElementGeometryProblem {
  nonFinite,
  invalidSize,
  startsOutsideCanvas,
  extendsOutsideCanvas,
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
