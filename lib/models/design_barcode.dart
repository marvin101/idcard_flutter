import 'dart:convert';

import 'package:barcode/barcode.dart';

const designBarcodeSymbologies = <String>{
  'code128',
  'code39',
  'ean13',
  'data_matrix',
};

Barcode designBarcode(String symbology) => switch (symbology) {
  'code39' => Barcode.code39(),
  'ean13' => Barcode.ean13(),
  'data_matrix' => Barcode.dataMatrix(),
  _ => Barcode.code128(),
};

String designBarcodeLabel(String symbology) => switch (symbology) {
  'code39' => 'Code 39',
  'ean13' => 'EAN-13',
  'data_matrix' => 'Data Matrix',
  _ => 'Code 128',
};

bool isDesignBarcodeSquare(String symbology) => symbology == 'data_matrix';

String? designBarcodeValidation(String data, String symbology) {
  if (!designBarcodeSymbologies.contains(symbology)) {
    return 'Unsupported barcode format';
  }
  if (data.isEmpty) return 'Barcode content is empty';
  final bytes = utf8.encode(data).length;
  final maximumBytes = switch (symbology) {
    'code128' => 80,
    'code39' => 40,
    'ean13' => 13,
    _ => 1000,
  };
  if (bytes > maximumBytes) {
    return '${designBarcodeLabel(symbology)} content exceeds $maximumBytes UTF-8 bytes';
  }
  if (symbology == 'code128' &&
      data.runes.any((codePoint) => codePoint < 32 || codePoint > 126)) {
    return 'Invalid Code 128 content';
  }
  if (!designBarcode(symbology).isValid(data)) {
    return 'Invalid ${designBarcodeLabel(symbology)} content';
  }
  return null;
}

bool isDesignBarcodeDataSupported(String data, String symbology) =>
    designBarcodeValidation(data, symbology) == null;
