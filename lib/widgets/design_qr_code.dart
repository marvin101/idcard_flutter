import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';

import '../models/design_qr.dart';

class DesignQrCode extends StatelessWidget {
  const DesignQrCode({
    super.key,
    required this.data,
    required this.color,
    required this.backgroundColor,
    required this.quietZone,
    required this.errorCorrection,
  });

  final String data;
  final Color color;
  final Color backgroundColor;
  final double quietZone;
  final String errorCorrection;

  @override
  Widget build(BuildContext context) {
    if (!isDesignQrDataSupported(data)) {
      return ColoredBox(
        key: const Key('design-qr-unavailable'),
        color: backgroundColor,
        child: Center(child: Icon(Icons.qr_code_2, color: color)),
      );
    }
    return ColoredBox(
      color: backgroundColor,
      child: Padding(
        padding: EdgeInsets.all(quietZone),
        child: CustomPaint(
          key: const Key('design-qr-code'),
          painter: _DesignQrPainter(
            data,
            color,
            designQrBarcode(errorCorrection),
          ),
        ),
      ),
    );
  }
}

class _DesignQrPainter extends CustomPainter {
  const _DesignQrPainter(this.data, this.color, this.barcode);

  final String data;
  final Color color;
  final Barcode barcode;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.isEmpty) return;
    final paint = Paint()..color = color;
    for (final element in barcode.make(
      data,
      width: size.width,
      height: size.height,
      drawText: false,
    )) {
      if (element case BarcodeBar(:final black) when black) {
        canvas.drawRect(
          Rect.fromLTWH(
            element.left,
            element.top,
            element.width,
            element.height,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DesignQrPainter oldDelegate) =>
      data != oldDelegate.data ||
      color != oldDelegate.color ||
      barcode != oldDelegate.barcode;
}
