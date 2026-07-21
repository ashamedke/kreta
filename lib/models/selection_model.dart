import 'package:flutter/foundation.dart';

enum ToolMode {
  select,
  drawArrow,
}

class SelectionModel extends ChangeNotifier {
  String? _selectedItemId;
  ToolMode _toolMode = ToolMode.select;

  String? get selectedItemId => _selectedItemId;
  ToolMode get toolMode => _toolMode;

  void selectItem(String? itemId) {
    if (_selectedItemId != itemId) {
      _selectedItemId = itemId;
      // If we selected something, automatically switch to select mode
      if (itemId != null && _toolMode != ToolMode.select) {
        _toolMode = ToolMode.select;
      }
      notifyListeners();
    }
  }

  void setToolMode(ToolMode mode) {
    if (_toolMode != mode) {
      _toolMode = mode;
      // If we switch to draw arrow, deselect the current item
      if (mode == ToolMode.drawArrow) {
        _selectedItemId = null;
      }
      notifyListeners();
    }
  }
}
