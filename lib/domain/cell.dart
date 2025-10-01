import 'package:meta/meta.dart';

/// Represents the kind of value carried by a [Cell].
enum CellType {
  /// Empty cells hold no value and serialise to an empty CSV field.
  empty,

  /// Textual values serialise exactly as written.
  text,

  /// Numeric values are stored as [num] and serialise using [num.toString()].
  number,

  /// Boolean values serialise to `TRUE` or `FALSE`.
  boolean,
}

/// A single cell within a [Sheet].
///
/// The class keeps track of the position to ease validation and rehydration.
@immutable
class Cell {
  const Cell({
    required this.row,
    required this.column,
    required this.type,
    this.value,
  }) : assert(row >= 0 && column >= 0, 'Cell coordinates must be >= 0.');

  /// Zero-based row index.
  final int row;

  /// Zero-based column index.
  final int column;

  /// The declared type of [value].
  final CellType type;

  /// The raw value. The runtime type matches [type].
  final Object? value;

  /// Creates a [Cell] by inspecting [value] to determine an appropriate [CellType].
  factory Cell.fromValue({
    required int row,
    required int column,
    Object? value,
  }) {
    if (value == null || (value is String && value.isEmpty)) {
      return Cell(row: row, column: column, type: CellType.empty, value: null);
    }

    if (value is bool) {
      return Cell(row: row, column: column, type: CellType.boolean, value: value);
    }

    if (value is num) {
      return Cell(row: row, column: column, type: CellType.number, value: value);
    }

    return Cell(
      row: row,
      column: column,
      type: CellType.text,
      value: value.toString(),
    );
  }

  /// Converts a CSV field into a [Cell].
  ///
  /// Empty fields produce [CellType.empty] cells. `TRUE`/`FALSE` map to
  /// [CellType.boolean]. Numeric strings are parsed as [num]. Everything else is
  /// kept as text.
  factory Cell.fromCsvField({
    required int row,
    required int column,
    required String field,
  }) {
    if (field.isEmpty) {
      return Cell.fromValue(row: row, column: column, value: null);
    }

    final normalised = field.trim();
    if (normalised.isEmpty) {
      return Cell.fromValue(row: row, column: column, value: '');
    }

    if (normalised.toUpperCase() == 'TRUE') {
      return Cell.fromValue(row: row, column: column, value: true);
    }

    if (normalised.toUpperCase() == 'FALSE') {
      return Cell.fromValue(row: row, column: column, value: false);
    }

    final numeric = num.tryParse(normalised);
    if (numeric != null) {
      return Cell.fromValue(row: row, column: column, value: numeric);
    }

    return Cell.fromValue(row: row, column: column, value: field);
  }

  /// Serialises the cell to a CSV-compatible field string.
  String toCsvField() {
    switch (type) {
      case CellType.empty:
        return '';
      case CellType.boolean:
        return (value as bool) ? 'TRUE' : 'FALSE';
      case CellType.number:
        return (value as num).toString();
      case CellType.text:
        return value.toString();
    }
  }

  /// Returns the runtime value casted to the expected Dart type for [type].
  T? typedValue<T>() => value as T?;
}
