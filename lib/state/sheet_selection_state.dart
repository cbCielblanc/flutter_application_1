import 'package:flutter/foundation.dart';

import '../application/formula/formula_evaluator.dart';
import '../domain/sheet.dart';

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

  static CellPosition? tryParse(String reference) {
    if (reference.isEmpty) {
      return null;
    }
    final upper = reference.toUpperCase();
    var index = 0;
    while (index < upper.length && _isLetter(upper.codeUnitAt(index))) {
      index++;
    }
    if (index == 0 || index == upper.length) {
      return null;
    }
    final columnLabel = upper.substring(0, index);
    final rowPart = upper.substring(index);
    final rowNumber = int.tryParse(rowPart);
    if (rowNumber == null || rowNumber <= 0) {
      return null;
    }
    var columnNumber = 0;
    for (final code in columnLabel.codeUnits) {
      columnNumber = columnNumber * 26 + (code - 64);
    }
    return CellPosition(rowNumber - 1, columnNumber - 1);
  }

  static bool _isLetter(int codeUnit) =>
      (codeUnit >= 65 && codeUnit <= 90) || (codeUnit >= 97 && codeUnit <= 122);
}

@immutable
class CellValueChange {
  const CellValueChange({
    required this.position,
    this.previousRaw,
    this.previousDisplay,
    this.newRaw,
    this.newDisplay,
  });

  final CellPosition position;
  final String? previousRaw;
  final String? previousDisplay;
  final String? newRaw;
  final String? newDisplay;
}

@immutable
class SelectionChange {
  const SelectionChange({required this.previous, required this.current});

  final CellPosition? previous;
  final CellPosition? current;
}

/// Manages the currently selected cell and the value being edited for a sheet.
class SheetSelectionState extends ChangeNotifier {
  SheetSelectionState({
    ValueChanged<Map<CellPosition, String>>? onValuesChanged,
    ValueChanged<CellValueChange>? onCellValueChanged,
    ValueChanged<SelectionChange>? onSelectionChanged,
  }) : _onValuesChanged = onValuesChanged,
       _onCellValueChanged = onCellValueChanged,
       _onSelectionChanged = onSelectionChanged;

  ValueChanged<Map<CellPosition, String>>? _onValuesChanged;
  ValueChanged<CellValueChange>? _onCellValueChanged;
  ValueChanged<SelectionChange>? _onSelectionChanged;

  set onValuesChanged(ValueChanged<Map<CellPosition, String>>? callback) {
    _onValuesChanged = callback;
  }

  set onCellValueChanged(ValueChanged<CellValueChange>? callback) {
    _onCellValueChanged = callback;
  }

  set onSelectionChanged(ValueChanged<SelectionChange>? callback) {
    _onSelectionChanged = callback;
  }

  void _emitValuesChanged() {
    final callback = _onValuesChanged;
    if (callback == null) {
      return;
    }
    callback(Map<CellPosition, String>.unmodifiable(_rawValues));
  }

  void _emitCellValueChange(CellValueChange change) {
    final callback = _onCellValueChanged;
    if (callback == null) {
      return;
    }
    callback(change);
  }

  void _emitSelectionChange(CellPosition? previous, CellPosition? current) {
    final callback = _onSelectionChanged;
    if (callback == null) {
      return;
    }
    callback(SelectionChange(previous: previous, current: current));
  }

  CellPosition? get activeCell => _activeCell;
  CellPosition? _activeCell;

  String get editingValue => _editingValue;
  String _editingValue = '';

  String? get activeCellLabel => _activeCell?.label;

  final Map<CellPosition, String> _rawValues = <CellPosition, String>{};
  final Map<CellPosition, String> _computedValues = <CellPosition, String>{};
  final Map<CellPosition, Set<CellPosition>> _dependencies =
      <CellPosition, Set<CellPosition>>{};
  final Map<CellPosition, Set<CellPosition>> _dependents =
      <CellPosition, Set<CellPosition>>{};

  /// Returns the computed value for [position], or an empty string when unset.
  String valueFor(CellPosition position) {
    final cached = _computedValues[position];
    if (cached != null) {
      return cached;
    }
    final raw = _rawValues[position];
    if (raw == null || raw.isEmpty) {
      _clearDependenciesFor(position);
      return '';
    }
    final references = <CellPosition>{};
    final computed =
        _evaluateRaw(
          raw,
          position,
          <CellPosition>{},
          dependencies: references,
        ) ??
        raw;
    _computedValues[position] = computed;
    _setDependencies(position, references);
    return computed;
  }

  /// Returns the raw value for [position], or an empty string when unset.
  String rawValueFor(CellPosition position) => _rawValues[position] ?? '';

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
    final change = _writeEditingValueToActiveCell();
    if (change != null) {
      _emitValuesChanged();
      _emitCellValueChange(change);
    }
    final previousActive = _activeCell;
    _activeCell = position;

    final newEditingValue = _rawValues[position] ?? valueFor(position);
    final didChangeEditingValue = _editingValue != newEditingValue;
    _editingValue = newEditingValue;

    if (previousActive != position) {
      _emitSelectionChange(previousActive, position);
    }

    if (change != null || previousActive != position || didChangeEditingValue) {
      notifyListeners();
    }
  }

  /// Commits the current editing value into the active cell, if any.
  void commitEditingValue() {
    final change = _writeEditingValueToActiveCell();
    if (change != null) {
      _emitValuesChanged();
      _emitCellValueChange(change);
      notifyListeners();
    }
  }

  /// Moves the selection by [rowDelta] / [columnDelta] within the sheet bounds.
  void moveSelection({
    required int rowCount,
    required int columnCount,
    int rowDelta = 0,
    int columnDelta = 0,
  }) {
    final active = _activeCell;
    if (active == null) {
      return;
    }
    final nextRow = (active.row + rowDelta).clamp(0, rowCount - 1);
    final nextColumn = (active.column + columnDelta).clamp(0, columnCount - 1);
    final nextPosition = CellPosition(nextRow, nextColumn);
    if (nextPosition == active) {
      return;
    }
    selectCell(nextPosition);
  }

  /// Clears the current selection and editing value.
  void clearSelection() {
    final hadSelection = _activeCell != null || _editingValue.isNotEmpty;
    final change = _writeEditingValueToActiveCell();
    if (change != null) {
      _emitValuesChanged();
      _emitCellValueChange(change);
    }
    final previous = _activeCell;
    _activeCell = null;
    _editingValue = '';
    if (previous != null) {
      _emitSelectionChange(previous, null);
    }
    if (hadSelection || change != null) {
      notifyListeners();
    }
  }

  /// Synchronises the internal cache with the content of [sheet].
  void syncFromSheet(Sheet sheet) {
    final nextRaw = <CellPosition, String>{};
    for (var r = 0; r < sheet.rows.length; r++) {
      final row = sheet.rows[r];
      for (var c = 0; c < row.length; c++) {
        final cell = row[c];
        final value = cell.value;
        if (value == null) {
          continue;
        }
        final text = value.toString();
        if (text.isEmpty) {
          continue;
        }
        nextRaw[CellPosition(r, c)] = text;
      }
    }

    final active = _activeCell;
    final isSame = mapEquals(_rawValues, nextRaw);
    final activeOutOfRange =
        active != null &&
        (active.row >= sheet.rowCount || active.column >= sheet.columnCount);

    if (isSame && !activeOutOfRange) {
      return;
    }

    _rawValues
      ..clear()
      ..addAll(nextRaw);
    _computedValues.clear();
    _dependencies.clear();
    _dependents.clear();

    for (final entry in _rawValues.entries) {
      final references = <CellPosition>{};
      final computed =
          _evaluateRaw(
            entry.value,
            entry.key,
            <CellPosition>{},
            dependencies: references,
          ) ??
          entry.value;
      _computedValues[entry.key] = computed;
      _setDependencies(entry.key, references);
    }

    if (activeOutOfRange) {
      final previous = _activeCell;
      _activeCell = null;
      _editingValue = '';
      _emitSelectionChange(previous, null);
      notifyListeners();
      return;
    }

    if (active != null) {
      final newEditingValue = _rawValues[active] ?? valueFor(active);
      if (_editingValue != newEditingValue) {
        _editingValue = newEditingValue;
        notifyListeners();
      }
    }
  }

  /// Sets the raw value for [position] programmatically.
  bool setCellRawValue(CellPosition position, String? rawValue) {
    final change = _applyRawValue(position, rawValue);
    if (change == null) {
      return false;
    }
    if (_activeCell == position) {
      _editingValue = rawValue ?? '';
    }
    _emitValuesChanged();
    _emitCellValueChange(change);
    notifyListeners();
    return true;
  }

  Map<CellPosition, String> exportRawValues() =>
      Map<CellPosition, String>.unmodifiable(_rawValues);

  CellValueChange? _writeEditingValueToActiveCell() {
    final active = _activeCell;
    if (active == null) {
      return null;
    }
    final raw = _editingValue;
    final normalised = raw.isEmpty ? null : raw;
    return _applyRawValue(active, normalised);
  }

  CellValueChange? _applyRawValue(CellPosition position, String? rawValue) {
    final previousRaw = _rawValues[position];
    final previousDisplay = _computedValues[position];

    if (rawValue == null || rawValue.isEmpty) {
      final removedRaw = _rawValues.remove(position);
      final removedDisplay = _computedValues.remove(position);
      final depsChanged = _clearDependenciesFor(position);
      final dependentsChanged = _recomputeDependents(
        position,
        <CellPosition>{},
      );
      if (removedRaw == null &&
          removedDisplay == null &&
          !depsChanged &&
          !dependentsChanged) {
        return null;
      }
      return CellValueChange(
        position: position,
        previousRaw: previousRaw,
        previousDisplay: previousDisplay,
        newRaw: null,
        newDisplay: null,
      );
    }

    final references = <CellPosition>{};
    final evaluated =
        _evaluateRaw(
          rawValue,
          position,
          <CellPosition>{},
          dependencies: references,
        ) ??
        rawValue;

    _rawValues[position] = rawValue;
    _computedValues[position] = evaluated;

    final depsChanged = _setDependencies(position, references);
    final dependentsChanged = _recomputeDependents(position, <CellPosition>{});

    final changedRaw = previousRaw != rawValue;
    final changedDisplay = previousDisplay != evaluated;

    if (!changedRaw && !changedDisplay && !depsChanged && !dependentsChanged) {
      return null;
    }

    return CellValueChange(
      position: position,
      previousRaw: previousRaw,
      previousDisplay: previousDisplay,
      newRaw: rawValue,
      newDisplay: evaluated,
    );
  }

  bool _clearDependenciesFor(CellPosition origin) {
    final previous = _dependencies.remove(origin);
    if (previous == null || previous.isEmpty) {
      return false;
    }
    for (final dependency in previous) {
      final dependents = _dependents[dependency];
      if (dependents == null) {
        continue;
      }
      dependents.remove(origin);
      if (dependents.isEmpty) {
        _dependents.remove(dependency);
      }
    }
    return true;
  }

  bool _setDependencies(CellPosition origin, Set<CellPosition> dependencies) {
    final previous = _dependencies[origin];
    final previousCopy = previous == null
        ? <CellPosition>{}
        : Set<CellPosition>.from(previous);
    final next = dependencies.isEmpty
        ? <CellPosition>{}
        : Set<CellPosition>.from(dependencies);

    if (previous != null) {
      for (final dependency in previous) {
        final dependents = _dependents[dependency];
        if (dependents == null) {
          continue;
        }
        dependents.remove(origin);
        if (dependents.isEmpty) {
          _dependents.remove(dependency);
        }
      }
    }

    if (next.isEmpty) {
      _dependencies.remove(origin);
    } else {
      final stored = Set<CellPosition>.unmodifiable(next);
      _dependencies[origin] = stored;
      for (final dependency in stored) {
        final dependents = _dependents.putIfAbsent(
          dependency,
          () => <CellPosition>{},
        );
        dependents.add(origin);
      }
    }

    return !setEquals(previousCopy, next);
  }

  bool _recomputeDependents(CellPosition origin, Set<CellPosition> visited) {
    if (!visited.add(origin)) {
      return false;
    }
    final dependents = _dependents[origin];
    if (dependents == null || dependents.isEmpty) {
      return false;
    }
    var changed = false;
    for (final dependent in List<CellPosition>.from(dependents)) {
      if (!visited.add(dependent)) {
        continue;
      }
      final raw = _rawValues[dependent];
      if (raw == null || raw.isEmpty) {
        final removedDisplay = _computedValues.remove(dependent) != null;
        final depsChanged = _clearDependenciesFor(dependent);
        changed = changed || removedDisplay || depsChanged;
        visited.remove(dependent);
        continue;
      }
      final references = <CellPosition>{};
      final evaluated =
          _evaluateRaw(
            raw,
            dependent,
            <CellPosition>{},
            dependencies: references,
          ) ??
          raw;
      final previousDisplay = _computedValues[dependent];
      _computedValues[dependent] = evaluated;
      final depsChanged = _setDependencies(dependent, references);
      if (previousDisplay != evaluated || depsChanged) {
        changed = true;
      }
      if (_recomputeDependents(dependent, visited)) {
        changed = true;
      }
      visited.remove(dependent);
    }
    return changed;
  }

  String? _evaluateRaw(
    String raw,
    CellPosition origin,
    Set<CellPosition> stack, {
    Set<CellPosition>? dependencies,
  }) {
    final trimmedLeading = raw.trimLeft();
    if (!trimmedLeading.startsWith('=')) {
      return raw;
    }
    if (!stack.add(origin)) {
      return '#CYCLE';
    }
    try {
      final result = FormulaEvaluator.evaluate(
        trimmedLeading,
        lookup: (reference) =>
            _resolveReference(reference, stack, dependencies),
      );
      return result ?? trimmedLeading;
    } on _UnresolvedReference {
      return 'WAIT ';
    } finally {
      stack.remove(origin);
    }
  }

  double? _resolveReference(
    String reference,
    Set<CellPosition> stack,
    Set<CellPosition>? dependencies,
  ) {
    final position = CellPosition.tryParse(reference);
    if (position == null) {
      return null;
    }
    dependencies?.add(position);
    final raw = _rawValues[position];
    if (raw != null && raw.trim().startsWith('=')) {
      final evaluated = _evaluateRaw(raw, position, stack);
      final parsed = double.tryParse(evaluated ?? '');
      if (parsed == null) {
        throw _UnresolvedReference(position);
      }
      return parsed;
    }
    final text = raw ?? _computedValues[position];
    final parsed = double.tryParse(text ?? '');
    if (parsed == null) {
      throw _UnresolvedReference(position);
    }
    return parsed;
  }
}

class _UnresolvedReference implements Exception {
  const _UnresolvedReference(this.position);

  final CellPosition position;
}
