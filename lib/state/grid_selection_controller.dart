// lib/state/grid_selection_controller.dart
// Controlador liviano para selection estable (rowId/colId) + indices actuales.

import 'package:flutter/foundation.dart';

import '../models/cell_ref.dart';

class GridSelectionController extends ChangeNotifier {
  GridSelectionController({CellRef? initial}) : _cellRef = initial;

  CellRef? _cellRef;
  int rowIndex = 0;
  int colIndex = 0;

  CellRef? get cellRef => _cellRef;

  void update({
    required int rowIndex,
    required int colIndex,
    required CellRef? cellRef,
  }) {
    this.rowIndex = rowIndex;
    this.colIndex = colIndex;
    if (_cellRef == cellRef) return;
    _cellRef = cellRef;
    notifyListeners();
  }

  void clear() {
    _cellRef = null;
    rowIndex = 0;
    colIndex = 0;
    notifyListeners();
  }
}
