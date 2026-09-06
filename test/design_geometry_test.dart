import 'package:flutter_test/flutter_test.dart';
import 'package:idcard_flutter/models/card_template.dart';
import 'package:idcard_flutter/models/design_geometry.dart';

void main() {
  const landscape = DesignCanvas(width: 100, height: 50);
  const portrait = DesignCanvas(
    width: 50,
    height: 100,
    orientation: 'portrait',
  );

  DesignElement element({
    String id = 'element',
    double x = 10,
    double y = 20,
    double width = 30,
    double height = 10,
    double rotation = 17,
    bool locked = true,
    bool visible = false,
  }) => DesignElement(
    id: id,
    type: DesignElementType.boundText,
    x: x,
    y: y,
    width: width,
    height: height,
    rotation: rotation,
    zIndex: 9,
    locked: locked,
    visible: visible,
    style: const {'font_size': 4.0, 'color': '#112233'},
    data: const {'field': 'full_name'},
  );

  DesignDocument document(DesignCanvas canvas, List<DesignElement> elements) =>
      DesignDocument(canvas: canvas, elements: elements);

  void expectNonGeometryPreserved(DesignElement actual, DesignElement source) {
    expect(actual.id, source.id);
    expect(actual.type, source.type);
    expect(actual.rotation, source.rotation);
    expect(actual.zIndex, source.zIndex);
    expect(actual.locked, source.locked);
    expect(actual.visible, source.visible);
    expect(actual.style, source.style);
    expect(actual.data, source.data);
  }

  test('keep positions preserves geometry in both orientation directions', () {
    for (final pair in [(landscape, portrait), (portrait, landscape)]) {
      final source = element();
      final resized = resizeDesignDocument(
        document(pair.$1, [source]),
        pair.$2,
        CanvasResizeStrategy.keepPositions,
      );
      expect(resized.elements.single.toJson(), source.toJson());
    }
  });

  test('scale proportionally transforms geometry in both directions', () {
    final source = element();
    final portraitResult = resizeDesignDocument(
      document(landscape, [source]),
      portrait,
      CanvasResizeStrategy.scaleProportionally,
    ).elements.single;
    expect(
      [
        portraitResult.x,
        portraitResult.y,
        portraitResult.width,
        portraitResult.height,
      ],
      [5, 40, 15, 20],
    );
    expect(portraitResult.style['font_size'], 4);
    expectNonGeometryPreserved(portraitResult, source);

    final landscapeResult = resizeDesignDocument(
      document(portrait, [source]),
      landscape,
      CanvasResizeStrategy.scaleProportionally,
    ).elements.single;
    expect(
      [
        landscapeResult.x,
        landscapeResult.y,
        landscapeResult.width,
        landscapeResult.height,
      ],
      [20, 10, 60, 5],
    );
  });

  test('fit handles all edges, footer, and oversized elements', () {
    final elements = [
      element(id: 'top-left', x: -3, y: -4, width: 10, height: 8),
      element(id: 'right', x: 48, y: 10, width: 10, height: 8),
      element(id: 'footer', x: 0, y: 45, width: 100, height: 5),
      element(id: 'oversized', x: 2, y: 3, width: 80, height: 120),
    ];
    final resized = resizeDesignDocument(
      document(landscape, elements),
      portrait,
      CanvasResizeStrategy.fitToCanvas,
    );
    final byId = {for (final item in resized.elements) item.id: item};
    expect((byId['top-left']!.x, byId['top-left']!.y), (0, 0));
    expect(byId['right']!.x, 40);
    expect(
      (
        byId['footer']!.x,
        byId['footer']!.y,
        byId['footer']!.width,
        byId['footer']!.height,
      ),
      (0, 45, 50, 5),
    );
    expect(
      (
        byId['oversized']!.x,
        byId['oversized']!.y,
        byId['oversized']!.width,
        byId['oversized']!.height,
      ),
      (0, 0, 50, 100),
    );
    for (var index = 0; index < elements.length; index++) {
      expectNonGeometryPreserved(resized.elements[index], elements[index]);
      expect(
        validateElementGeometry(resized.elements[index], portrait),
        isEmpty,
      );
    }
  });

  test('fit also clamps portrait elements when changing to landscape', () {
    final source = element(x: 45, y: 95, width: 10, height: 10);
    final result = resizeDesignDocument(
      document(portrait, [source]),
      landscape,
      CanvasResizeStrategy.fitToCanvas,
    ).elements.single;
    expect((result.x, result.y), (45, 40));
  });

  test('custom dimensions use independent scale factors', () {
    final result = resizeDesignDocument(
      document(landscape, [element()]),
      const DesignCanvas(width: 125, height: 80),
      CanvasResizeStrategy.scaleProportionally,
    ).elements.single;
    expect(
      (result.x, result.y, result.width, result.height),
      (12.5, 32, 37.5, 16),
    );
  });

  test('transformed geometry survives API serialization and reopen', () {
    final resized = resizeDesignDocument(
      document(landscape, [element()]),
      portrait,
      CanvasResizeStrategy.scaleProportionally,
    );
    final saved = CardTemplate(name: 'Test2', document: resized);
    final reopened = CardTemplate.fromApi(saved.toApi());
    expect(reopened.toApi(), saved.toApi());
  });

  test(
    'geometry validation reports each invalid condition without mutation',
    () {
      final outside = element(x: -1, y: 45, width: 102, height: 10);
      expect(
        validateElementGeometry(outside, landscape),
        containsAll({
          ElementGeometryProblem.startsOutsideCanvas,
          ElementGeometryProblem.extendsOutsideCanvas,
        }),
      );
      expect(
        validateElementGeometry(element(x: double.nan, width: -1), landscape),
        contains(ElementGeometryProblem.nonFinite),
      );
      expect(
        validateElementGeometry(element(width: 0), landscape),
        contains(ElementGeometryProblem.invalidSize),
      );
      expect(outside.x, -1);
      expect(outside.width, 102);
    },
  );
}
