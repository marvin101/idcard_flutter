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
    this.frontOffsetXmm = 0,
    this.frontOffsetYmm = 0,
    this.backOffsetXmm = 0,
    this.backOffsetYmm = 0,
  });

  final PrintLayoutMode mode;
  final PrintPaperSize paperSize;
  final PrintPaperOrientation orientation;
  final double marginMm;
  final double gapMm;
  final bool cropMarks;
  final PrintSides sides;
  final DuplexFlipEdge flipEdge;
  final double frontOffsetXmm;
  final double frontOffsetYmm;
  final double backOffsetXmm;
  final double backOffsetYmm;

  bool get isDuplex => sides == PrintSides.duplex;

  PrintSheetSettings copyWith({
    PrintLayoutMode? mode,
    PrintPaperSize? paperSize,
    PrintPaperOrientation? orientation,
    double? marginMm,
    double? gapMm,
    bool? cropMarks,
    PrintSides? sides,
    DuplexFlipEdge? flipEdge,
    double? frontOffsetXmm,
    double? frontOffsetYmm,
    double? backOffsetXmm,
    double? backOffsetYmm,
  }) => PrintSheetSettings(
    mode: mode ?? this.mode,
    paperSize: paperSize ?? this.paperSize,
    orientation: orientation ?? this.orientation,
    marginMm: marginMm ?? this.marginMm,
    gapMm: gapMm ?? this.gapMm,
    cropMarks: cropMarks ?? this.cropMarks,
    sides: sides ?? this.sides,
    flipEdge: flipEdge ?? this.flipEdge,
    frontOffsetXmm: frontOffsetXmm ?? this.frontOffsetXmm,
    frontOffsetYmm: frontOffsetYmm ?? this.frontOffsetYmm,
    backOffsetXmm: backOffsetXmm ?? this.backOffsetXmm,
    backOffsetYmm: backOffsetYmm ?? this.backOffsetYmm,
  );

  Map<String, Object> toJson() => {
    'mode': mode.name,
    'paper_size': paperSize.name,
    'orientation': orientation.name,
    'margin_mm': marginMm,
    'gap_mm': gapMm,
    'crop_marks': cropMarks,
    'sides': sides.name,
    'flip_edge': flipEdge.name,
    'front_offset_x_mm': frontOffsetXmm,
    'front_offset_y_mm': frontOffsetYmm,
    'back_offset_x_mm': backOffsetXmm,
    'back_offset_y_mm': backOffsetYmm,
  };

  factory PrintSheetSettings.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, String key, T fallback) {
      final name = json[key];
      for (final value in values) {
        if (value.name == name) return value;
      }
      return fallback;
    }

    double number(String key, double fallback) =>
        (json[key] as num?)?.toDouble() ?? fallback;

    return PrintSheetSettings(
      mode: enumValue(
        PrintLayoutMode.values,
        'mode',
        PrintLayoutMode.oneCardPerPage,
      ),
      paperSize: enumValue(
        PrintPaperSize.values,
        'paper_size',
        PrintPaperSize.a4,
      ),
      orientation: enumValue(
        PrintPaperOrientation.values,
        'orientation',
        PrintPaperOrientation.portrait,
      ),
      marginMm: number('margin_mm', 10),
      gapMm: number('gap_mm', 4),
      cropMarks: json['crop_marks'] == true,
      sides: enumValue(PrintSides.values, 'sides', PrintSides.frontOnly),
      flipEdge: enumValue(
        DuplexFlipEdge.values,
        'flip_edge',
        DuplexFlipEdge.longEdge,
      ),
      frontOffsetXmm: number('front_offset_x_mm', 0),
      frontOffsetYmm: number('front_offset_y_mm', 0),
      backOffsetXmm: number('back_offset_x_mm', 0),
      backOffsetYmm: number('back_offset_y_mm', 0),
    );
  }

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
    final offsets = [
      settings.frontOffsetXmm,
      settings.frontOffsetYmm,
      settings.backOffsetXmm,
      settings.backOffsetYmm,
    ];
    if (offsets.any((value) => !value.isFinite || value.abs() > 20)) {
      return PrintSheetPlan._invalid(
        settings,
        cardWidthMm,
        cardHeightMm,
        cardCount,
        'Calibration offsets must be between -20 and 20 mm.',
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
    final startX = settings.marginMm + (usableWidth - contentWidth) / 2;
    final startY = settings.marginMm + (usableHeight - contentHeight) / 2;
    final activeOffsets = [
      (settings.frontOffsetXmm, settings.frontOffsetYmm),
      if (settings.isDuplex) (settings.backOffsetXmm, settings.backOffsetYmm),
    ];
    if (activeOffsets.any(
      (offset) =>
          startX + offset.$1 < 0 ||
          startY + offset.$2 < 0 ||
          startX + contentWidth + offset.$1 > settings.pageWidthMm ||
          startY + contentHeight + offset.$2 > settings.pageHeightMm,
    )) {
      return PrintSheetPlan._invalid(
        settings,
        cardWidthMm,
        cardHeightMm,
        cardCount,
        'Calibration moves part of the card grid outside the selected paper.',
      );
    }
    return PrintSheetPlan(
      settings: settings,
      cardWidthMm: cardWidthMm,
      cardHeightMm: cardHeightMm,
      columns: columns,
      rows: rows,
      startXmm: startX,
      startYmm: startY,
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

  double leftFor(int indexOnPage, {bool back = false}) =>
      startXmm +
      (indexOnPage % columns) * (cardWidthMm + settings.gapMm) +
      (back ? settings.backOffsetXmm : settings.frontOffsetXmm);

  double topFor(int indexOnPage, {bool back = false}) =>
      startYmm +
      (indexOnPage ~/ columns) * (cardHeightMm + settings.gapMm) +
      (back ? settings.backOffsetYmm : settings.frontOffsetYmm);

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

class PrintPreset {
  const PrintPreset({
    required this.id,
    required this.name,
    required this.settings,
  });

  final String id;
  final String name;
  final PrintSheetSettings settings;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'settings': settings.toJson(),
  };

  factory PrintPreset.fromJson(Map<String, dynamic> json) => PrintPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    settings: PrintSheetSettings.fromJson(
      Map<String, dynamic>.from(json['settings'] as Map),
    ),
  );
}
