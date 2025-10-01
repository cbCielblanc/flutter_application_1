import 'package:csv/csv.dart';
import 'package:meta/meta.dart';

import 'cell.dart';

/// A tabular collection of [Cell]s within a [Workbook].
///
/// Invariants:
/// * A sheet must expose at least one row and one column. Empty sheets are not
///   supported and should instead be omitted from the workbook.
/// * All rows must have the same number of columns. Gaps are represented by
///   [CellType.empty] cells.
@immutable
class Sheet {
  Sheet({
    required this.name,
    required List<List<Cell>> rows,
  })  : assert(name.isNotEmpty, 'Sheets must be named.'),
        assert(rows.isNotEmpty, 'A sheet must contain at least one row.'),
        assert(
          rows.every((row) => row.length == rows.first.length),
          'All rows must have the same column count.',
        ),
        _rows = rows
            .map((row) => List<Cell>.unmodifiable(row))
            .toList(growable: false);

  /// Unique sheet name inside its workbook.
  final String name;

  final List<List<Cell>> _rows;

  /// Access to the rows as an immutable list.
  List<List<Cell>> get rows =>
      _rows.map((row) => List<Cell>.unmodifiable(row)).toList(growable: false);

  /// Number of rows.
  int get rowCount => _rows.length;

  /// Number of columns.
  int get columnCount => _rows.isEmpty ? 0 : _rows.first.length;

  /// Serialises the sheet to CSV text.
  ///
  /// The default CSV codec is used and matches Excel/Google Sheets escaping
  /// behaviour.
  String toCsv({String fieldDelimiter = ',', String eol = '\n'}) {
    final converter = const ListToCsvConverter();
    final table = _rows
        .map(
          (row) => row
              .map(
                (cell) => cell.toCsvField(),
              )
              .toList(growable: false),
        )
        .toList(growable: false);
    return converter.convert(
      table,
      fieldDelimiter: fieldDelimiter,
      eol: eol,
    );
  }

  /// Builds a [Sheet] from CSV data.
  factory Sheet.fromCsv({
    required String name,
    required String csv,
    String fieldDelimiter = ',',
  }) {
    final converter = const CsvToListConverter(shouldParseNumbers: false);
    final rows = converter.convert(csv, fieldDelimiter: fieldDelimiter);
    if (rows.isEmpty) {
      throw const FormatException('A sheet must contain at least one row.');
    }

    final normalisedRows = <List<Cell>>[];
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final cells = <Cell>[];
      for (var c = 0; c < row.length; c++) {
        final field = row[c];
        if (field is String) {
          cells.add(Cell.fromCsvField(row: r, column: c, field: field));
        } else if (field is num) {
          cells.add(Cell.fromValue(row: r, column: c, value: field));
        } else if (field is bool) {
          cells.add(Cell.fromValue(row: r, column: c, value: field));
        } else {
          cells.add(Cell.fromValue(row: r, column: c, value: field.toString()));
        }
      }

      normalisedRows.add(List<Cell>.unmodifiable(cells));
    }

    if (normalisedRows.first.isEmpty) {
      throw const FormatException('A sheet must contain at least one column.');
    }

    return Sheet(name: name, rows: normalisedRows);
  }

  /// Creates a sheet using string rows. Convenience for tests/fixtures.
  factory Sheet.fromRows({
    required String name,
    required List<List<Object?>> rows,
  }) {
    final normalisedRows = <List<Cell>>[];
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final cells = <Cell>[];
      for (var c = 0; c < row.length; c++) {
        cells.add(Cell.fromValue(row: r, column: c, value: row[c]));
      }
      normalisedRows.add(List<Cell>.unmodifiable(cells));
    }

    return Sheet(name: name, rows: normalisedRows);
  }
}
