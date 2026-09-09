import 'dart:convert';

import 'package:barcode/barcode.dart';

const designQrMaxBytes = 1000;

bool isDesignQrDataSupported(String data) =>
    data.isNotEmpty && utf8.encode(data).length <= designQrMaxBytes;

Barcode designQrBarcode(String errorCorrection) => Barcode.qrCode(
  errorCorrectLevel: switch (errorCorrection) {
    'low' => BarcodeQRCorrectionLevel.low,
    'quartile' => BarcodeQRCorrectionLevel.quartile,
    'high' => BarcodeQRCorrectionLevel.high,
    _ => BarcodeQRCorrectionLevel.medium,
  },
);
