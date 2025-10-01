import 'package:flutter/foundation.dart';

/// Represents the zero-based position of a cell in the sheet grid.
@immutable
class CellPosition {
  const CellPosition(this.row, this.column)
      : assert(row >= 0, 'row must be >= 0'),
        assert(column >= 0, 'column must be >= 0');

  final int row;
  final int column;

  String get label => _columnLabel(column) + (row + 1).toString();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CellPosition && other.row == row && other.column == column;
  }

  @override
  int get hashCode => Object.hash(row, column);

  static String _columnLabel(int columnIndex) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final buffer = StringBuffer();
    var index = columnIndex;
    do {
      final quotient = index ~/ letters.length;
      final remainder = index % letters.length;
      buffer.write(letters[remainder]);
      index = quotient - 1;
    } while (index >= 0);
    return buffer.toString().split('').reversed.join();
  }

  static String columnLabel(int columnIndex) => _columnLabel(columnIndex);
}

/// Manages the currently selected cell and the value being edited for a sheet.
class SheetSelectionState extends ChangeNotifier {
  CellPosition? get activeCell => _activeCell;
  CellPosition? _activeCell;

  String get editingValue => _editingValue;
  String _editingValue = '';

  String? get activeCellLabel => _activeCell?.label;

  final Map<CellPosition, String> _cellValues = <CellPosition, String>{};

  /// Returns the persisted value for [position], or an empty string when unset.
  String valueFor(CellPosition position) => _cellValues[position] ?? '';

  /// Updates the current editing value without committing it to the sheet.
  void updateEditingValue(String value) {
    if (value == _editingValue) {
      return;
    }
    _editingValue = value;
    notifyListeners();
  }

  /// Selects a new [position] and loads its persisted value into the editor.
  void selectCell(CellPosition position) {
    final didWrite = _writeEditingValueToActiveCell();
    final previousActive = _activeCell;
    _activeCell = position;

    final newEditingValue = valueFor(position);
    final didChangeEditingValue = _editingValue != newEditingValue;
    _editingValue = newEditingValue;

    if (didWrite || previousActive != position || didChangeEditingValue) {
      notifyListeners();
    }
  }

  /// Commits the current editing value into the active cell, if any.
  void commitEditingValue() {
    if (_writeEditingValueToActiveCell()) {
      notifyListeners();
    }
  }

  /// Clears the current selection and editing value.
  void clearSelection() {
    final hadSelection = _activeCell != null || _editingValue.isNotEmpty;
    final didWrite = _writeEditingValueToActiveCell();
    _activeCell = null;
    _editingValue = '';
    if (hadSelection || didWrite) {
      notifyListeners();
    }
  }

  bool _writeEditingValueToActiveCell() {
    final active = _activeCell;
    if (active == null) {
      return false;
    }
    final currentValue = _cellValues[active];
    if (_editingValue.isEmpty) {
      if (currentValue == null) {
        return false;
      }
      _cellValues.remove(active);
      return true;
    }
    if (currentValue == _editingValue) {
      return false;
    }
    _cellValues[active] = _editingValue;
    return true;
  }
}
