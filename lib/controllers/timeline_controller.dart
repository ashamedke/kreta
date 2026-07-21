import 'package:flutter/foundation.dart';

class TimelineController extends ChangeNotifier {
  double _pixelsPerMs = 0.1; // Default zoom level: 100px per second
  double _scrollOffset = 0.0;
  
  double get pixelsPerMs => _pixelsPerMs;
  double get scrollOffset => _scrollOffset;

  void zoomIn() {
    _pixelsPerMs = (_pixelsPerMs * 1.2).clamp(0.01, 2.0);
    notifyListeners();
  }

  void zoomOut() {
    _pixelsPerMs = (_pixelsPerMs / 1.2).clamp(0.01, 2.0);
    notifyListeners();
  }

  void setZoom(double value) {
    _pixelsPerMs = value.clamp(0.01, 2.0);
    notifyListeners();
  }

  void updateScrollOffset(double offset) {
    if (_scrollOffset != offset) {
      _scrollOffset = offset;
      notifyListeners();
    }
  }
}
