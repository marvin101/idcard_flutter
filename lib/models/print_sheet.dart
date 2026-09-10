import 'dart:math' as math;

enum PrintLayoutMode { oneCardPerPage, sheet }

enum PrintPaperSize { a4, letter }

enum PrintPaperOrientation { portrait, landscape }

enum PrintSides { frontOnly, duplex }

enum DuplexFlipEdge { longEdge, shortEdge }

class PrintSheetSettings {
  const PrintSheetSettings({
    this.mode = PrintLayoutMode.oneCardPerPage,
    this.paperSize = PrintPaperSize.a4,
    this.orientation = PrintPaperOrientation.portrait,
    this.marginMm = 10,
    this.gapMm = 4,
    this.cropMarks = false,
    this.sides = PrintSides.frontOnly,
    this.flipEdge = DuplexFlipEdge.longEdge,
  });

  final PrintLayoutMode mode;
  final PrintPaperSize paperSize;
  final PrintPaperOrientation orientation;
  final double marginMm;
  final double gapMm;
  final bool cropMarks;
  final PrintSides sides;
  final DuplexFlipEdge flipEdge;

  bool get isDuplex => sides == PrintSides.duplex;

  double get pageWidthMm {
    final portraitWidth = paperSize == PrintPaperSize.a4 ? 210.0 : 215.9;
    final portraitHeight = paperSize == PrintPaperSize.a4 ? 297.0 : 279.4;
    return orientation == PrintPaperOrientation.portrait
        ? portraitWidth
        : portraitHeight;
  }

  double get pageHeightMm {
    final portraitWidth = paperSize == PrintPaperSize.a4 ? 210.0 : 215.9;
    final portraitHeight = paperSize == PrintPaperSize.a4 ? 297.0 : 279.4;
    return orientation == PrintPaperOrientation.portrait
        ? portraitHeight
        : portraitWidth;
  }

  String get paperLabel => paperSize == PrintPaperSize.a4 ? 'A4' : 'Letter';

  String get orientationLabel =>
      orientation == PrintPaperOrientation.portrait ? 'portrait' : 'landscape';
}

class PrintSheetPlan {
  const PrintSheetPlan({
    required this.settings,
    required this.cardWidthMm,
    required this.cardHeightMm,
    required this.columns,
    required this.rows,
    required this.startXmm,
    required this.startYmm,
    required this.cardCount,
    this.validationError,
  });

  factory PrintSheetPlan.calculate({
    required PrintSheetSettings settings,
    required double cardWidthMm,
    required double cardHeightMm,
    required int cardCount,
  }) {
    if (!cardWidthMm.isFinite ||
        !cardHeightMm.isFinite ||
        cardWidthMm <= 0 ||
        cardHeightMm <= 0) {
      return PrintSheetPlan._invalid(
        settings,
        cardWidthMm,
        cardHeightMm,
        cardCount,
        'Card dimensions must be greater than zero.',
      );
    }
    if (settings.mode == PrintLayoutMode.oneCardPerPage) {
      return PrintSheetPlan(
        settings: settings,
        cardWidthMm: cardWidthMm,
        cardHeightMm: cardHeightMm,
        columns: 1,
        rows: 1,
        startXmm: 0,
        startYmm: 0,
        cardCount: cardCount,
      );
    }
    if (!settings.marginMm.isFinite ||
        !settings.gapMm.isFinite ||
        settings.marginMm < 0 ||
        settings.gapMm < 0) {
      return PrintSheetPlan._invalid(
        settings,
        cardWidthMm,
        cardHeightMm,
        cardCount,
        'Margins and spacing must be zero or greater.',
      );
    }

    final usableWidth = settings.pageWidthMm - settings.marginMm * 2;
    final usableHeight = settings.pageHeightMm - settings.marginMm * 2;
    if (usableWidth <= 0 || usableHeight <= 0) {
      return PrintSheetPlan._invalid(
        settings,
        cardWidthMm,
        cardHeightMm,
        cardCount,
        'Margins leave no printable sheet area.',
      );
    }
    final columns =
        ((usableWidth + settings.gapMm) / (cardWidthMm + settings.gapMm))
            .floor();
    final rows =
        ((usableHeight + settings.gapMm) / (cardHeightMm + settings.gapMm))
            .floor();
    if (columns < 1 || rows < 1) {
      return PrintSheetPlan._invalid(
        settings,
        cardWidthMm,
        cardHeightMm,
        cardCount,
        'The card does not fit on the selected paper without scaling or clipping.',
      );
    }

    final contentWidth = columns * cardWidthMm + (columns - 1) * settings.gapMm;
    final contentHeight = rows * cardHeightMm + (rows - 1) * settings.gapMm;
    return PrintSheetPlan(
      settings: settings,
      cardWidthMm: cardWidthMm,
      cardHeightMm: cardHeightMm,
      columns: columns,
      rows: rows,
      startXmm: settings.marginMm + (usableWidth - contentWidth) / 2,
      startYmm: settings.marginMm + (usableHeight - contentHeight) / 2,
      cardCount: math.max(0, cardCount),
    );
  }

  const PrintSheetPlan._invalid(
    this.settings,
    this.cardWidthMm,
    this.cardHeightMm,
    this.cardCount,
    this.validationError,
  ) : columns = 0,
      rows = 0,
      startXmm = 0,
      startYmm = 0;

  final PrintSheetSettings settings;
  final double cardWidthMm;
  final double cardHeightMm;
  final int columns;
  final int rows;
  final double startXmm;
  final double startYmm;
  final int cardCount;
  final String? validationError;

  bool get isValid => validationError == null;
  int get cardsPerPage => columns * rows;
  int get pageCount => cardCount == 0 || cardsPerPage == 0
      ? 0
      : (cardCount + cardsPerPage - 1) ~/ cardsPerPage;
  int get physicalSheetCount => pageCount;
  int get pdfPageCount => pageCount * (settings.isDuplex ? 2 : 1);

  double leftFor(int indexOnPage) =>
      startXmm + (indexOnPage % columns) * (cardWidthMm + settings.gapMm);

  double topFor(int indexOnPage) =>
      startYmm + (indexOnPage ~/ columns) * (cardHeightMm + settings.gapMm);

  int backSlotFor(int frontSlot, DuplexFlipEdge flipEdge) {
    if (frontSlot < 0 || frontSlot >= cardsPerPage) {
      throw RangeError.range(frontSlot, 0, cardsPerPage - 1, 'frontSlot');
    }
    final row = frontSlot ~/ columns;
    final column = frontSlot % columns;
    final mirrorHorizontally = flipEdge == DuplexFlipEdge.longEdge
        ? settings.orientation == PrintPaperOrientation.portrait
        : settings.orientation == PrintPaperOrientation.landscape;
    final backRow = mirrorHorizontally ? row : rows - 1 - row;
    final backColumn = mirrorHorizontally ? columns - 1 - column : column;
    return backRow * columns + backColumn;
  }
}
