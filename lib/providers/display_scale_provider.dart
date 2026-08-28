import 'package:flutter/foundation.dart';

class DisplayScaleProvider extends ChangeNotifier {
  static const List<double> _steps = [0.75, 0.9, 1.0, 1.1, 1.25, 1.5];
  static const double minScale = 0.75;
  static const double maxScale = 1.5;

  double _scale = 1.0;

  double get scale => _scale;
  int get percentage => (scale * 100).round();
  bool get canZoomIn => scale < maxScale;
  bool get canZoomOut => scale > minScale;

  void zoomIn() {
    if (!canZoomIn) return;
    setScale(_steps.firstWhere((step) => step > scale));
  }

  void zoomOut() {
    if (!canZoomOut) return;
    setScale(_steps.lastWhere((step) => step < scale));
  }

  void setScale(double value) {
    final nextScale = value.clamp(minScale, maxScale).toDouble();
    if ((nextScale - _scale).abs() < 0.001) return;
    _scale = nextScale;
    notifyListeners();
  }

  void reset() {
    setScale(1.0);
  }
}

