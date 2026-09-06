import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// Bundled card fonts.
///
/// Flutter font registration is handled exclusively by pubspec.yaml, where
/// every CardNotoSans face has its correct FontWeight descriptor.
///
/// This class only loads the immutable font bytes needed by PDF export.
/// Dynamically registering all faces again through FontLoader would lose the
/// per-face weight metadata and can cause Flutter to select the wrong face.
class DesignFonts {
  static const names = {
    100: 'Thin',
    200: 'ExtraLight',
    300: 'Light',
    400: 'Regular',
    500: 'Medium',
    600: 'SemiBold',
    700: 'Bold',
    800: 'ExtraBold',
    900: 'Black',
  };

  static Future<Map<int, ByteData>>? _loaded;

  static Future<Map<int, ByteData>> load() {
    return _loaded ??= _load();
  }

  static Future<Map<int, ByteData>> _load() async {
    final data = <int, ByteData>{};

    for (final entry in names.entries) {
      data[entry.key] = await rootBundle.load(
        'assets/fonts/NotoSans-${entry.value}.ttf',
      );
    }

    return Map.unmodifiable(data);
  }

  static Future<Map<int, pw.Font>> pdfFonts() async {
    final data = await load();

    return {
      for (final entry in data.entries) entry.key: pw.Font.ttf(entry.value),
    };
  }

  static void validatePdfText(String text) {
    // The PDF library maps Unicode characters to glyphs but has no general
    // Indic GSUB/GPOS shaping. Reject rather than silently producing malformed
    // Devanagari text.
    if (RegExp(r'[\u0900-\u097F\uA8E0-\uA8FF]').hasMatch(text)) {
      throw UnsupportedError(
        'PDF export cannot reliably shape Devanagari text yet. '
        'The design and student data have not been changed.',
      );
    }
  }
}
