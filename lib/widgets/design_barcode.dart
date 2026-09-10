import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';

import '../models/design_barcode.dart';

class DesignBarcode extends StatelessWidget {
  const DesignBarcode({
    super.key,
    required this.data,
    required this.symbology,
    required this.color,
    required this.backgroundColor,
    required this.quietZone,
    required this.showText,
    required this.fontSize,
  });

  final String data;
  final String symbology;
  final Color color;
  final Color backgroundColor;
  final double quietZone;
  final bool showText;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (!isDesignBarcodeDataSupported(data, symbology)) {
      return ColoredBox(
        key: const Key('design-barcode-unavailable'),
        color: backgroundColor,
        child: Center(child: Icon(Icons.view_week_outlined, color: color)),
      );
    }
    return ColoredBox(
      color: backgroundColor,
      child: Padding(
        padding: EdgeInsets.all(quietZone),
        child: Column(
          children: [
            Expanded(
              child: SizedBox.expand(
                child: CustomPaint(
                  key: const Key('design-barcode'),
                  painter: _DesignBarcodePainter(
                    data,
                    color,
                    designBarcode(symbology),
                  ),
                ),
              ),
            ),
            if (showText && !isDesignBarcodeSquare(symbology))
              SizedBox(
                height: fontSize * 1.3,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    data,
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      inherit: false,
                      color: color,
                      fontFamily: 'CardNotoSans',
                      fontSize: fontSize,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesignBarcodePainter extends CustomPainter {
  const _DesignBarcodePainter(this.data, this.color, this.barcode);

  final String data;
  final Color color;
  final Barcode barcode;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
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
  bool shouldRepaint(_DesignBarcodePainter oldDelegate) =>
      data != oldDelegate.data ||
      color != oldDelegate.color ||
      barcode.name != oldDelegate.barcode.name;
}
