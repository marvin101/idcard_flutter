import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/design_render_scene.dart';

/// Fonts are bundled and loaded offline. PDF font instances belong to each
/// export document; only immutable asset bytes and Flutter registration cache.
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
  static Future<Map<int, ByteData>> load() => _loaded ??= _load();
  static Future<Map<int, ByteData>> _load() async {
    final data = <int, ByteData>{};
    final loader = FontLoader(DesignRenderStyle.fontFamily);
    for (final entry in names.entries) {
      final bytes = await rootBundle.load(
        'assets/fonts/NotoSans-${entry.value}.ttf',
      );
      data[entry.key] = bytes;
      loader.addFont(Future.value(bytes));
    }
    await loader.load();
    return Map.unmodifiable(data);
  }

  static Future<Map<int, pw.Font>> pdfFonts() async => {
    for (final entry in (await load()).entries)
      entry.key: pw.Font.ttf(entry.value),
  };
  static void validatePdfText(String text) {
    // The PDF library maps Unicode characters to glyphs but has no Indic GSUB/
    // GPOS shaping. Reject instead of silently printing incorrect names.
    if (RegExp(r'[\u0900-\u097F\uA8E0-\uA8FF]').hasMatch(text)) {
      throw UnsupportedError(
        'PDF export cannot reliably shape Devanagari text yet. The design and student data have not been changed.',
      );
    }
  }
}
