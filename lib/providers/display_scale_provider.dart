import 'package:flutter/foundation.dart';

class DisplayScaleProvider extends ChangeNotifier {
  static const List<double> _steps = [0.75, 0.9, 1.0, 1.1, 1.25, 1.5];

  int _stepIndex = 2;

  double get scale => _steps[_stepIndex];
  int get percentage => (scale * 100).round();
  bool get canZoomIn => _stepIndex < _steps.length - 1;
  bool get canZoomOut => _stepIndex > 0;

  void zoomIn() {
    if (!canZoomIn) return;
    _stepIndex += 1;
    notifyListeners();
  }

  void zoomOut() {
    if (!canZoomOut) return;
    _stepIndex -= 1;
    notifyListeners();
  }

  void reset() {
    if (_stepIndex == 2) return;
    _stepIndex = 2;
    notifyListeners();
  }
}
