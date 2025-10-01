import 'dart:io';

import 'package:csv/csv.dart';

import '../domain/cell.dart';
import '../domain/sheet.dart';
import '../domain/workbook.dart';

/// Converts raw CSV fields into typed [Cell] instances and back.
class CsvCellFactory {
  const CsvCellFactory();

  /// Builds a [Cell] from the raw field emitted by the CSV parser.
  Cell fromField({
    required int row,
    required int column,
    required dynamic field,
  }) {
    if (field == null) {
      return Cell.fromValue(row: row, column: column, value: null);
    }

    if (field is bool || field is num) {
      return Cell.fromValue(row: row, column: column, value: field);
    }

    if (field is String) {
      if (field.isEmpty) {
        return Cell.fromValue(row: row, column: column, value: null);
      }

      final normalised = field.trim();
      final upper = normalised.toUpperCase();
      if (upper == 'TRUE') {
        return Cell.fromValue(row: row, column: column, value: true);
      }
      if (upper == 'FALSE') {
        return Cell.fromValue(row: row, column: column, value: false);
      }

      final numeric = num.tryParse(normalised);
      if (numeric != null) {
        return Cell.fromValue(row: row, column: column, value: numeric);
      }

      return Cell.fromValue(row: row, column: column, value: field);
    }

    return Cell.fromValue(
      row: row,
      column: column,
      value: field.toString(),
    );
  }

  /// Serialises a [Cell] to a CSV compatible field.
  String toField(Cell cell) => cell.toCsvField();
}

/// Provides helpers to load and save [Workbook] instances using CSV files.
class CsvService {
  const CsvService({CsvCellFactory? cellFactory})
      : _cellFactory = cellFactory ?? const CsvCellFactory();

  final CsvCellFactory _cellFactory;

  /// Loads a [Workbook] from a CSV [file].
  ///
  /// The service produces a workbook exposing a single sheet. The sheet name can
  /// be customised via [sheetName].
  Future<Workbook> loadFromCsv({
    required File file,
    String sheetName = 'Sheet1',
    String fieldDelimiter = ',',
  }) async {
    final raw = await file.readAsString();
    final converter = const CsvToListConverter(
      shouldParseNumbers: false,
      shouldParseNulls: false,
    );

    List<List<dynamic>> rows;
    try {
      rows = converter.convert(raw, fieldDelimiter: fieldDelimiter);
    } on FormatException catch (error) {
      throw FormatException('Invalid CSV content: ${error.message}');
    }

    if (rows.isEmpty) {
      throw const FormatException('CSV data must contain at least one row.');
    }

    final expectedColumnCount = rows.first.length;
    if (expectedColumnCount == 0) {
      throw const FormatException('CSV data must contain at least one column.');
    }

    final normalisedRows = <List<Cell>>[];
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      if (row.length != expectedColumnCount) {
        throw FormatException(
          'Row ${r + 1} has ${row.length} columns, expected '
          '$expectedColumnCount.',
        );
      }

      final cells = <Cell>[];
      for (var c = 0; c < row.length; c++) {
        cells.add(
          _cellFactory.fromField(row: r, column: c, field: row[c]),
        );
      }
      normalisedRows.add(List<Cell>.unmodifiable(cells));
    }

    final sheet = Sheet(name: sheetName, rows: normalisedRows);
    return Workbook(sheets: [sheet]);
  }

  /// Persists a [workbook] to [file] using CSV format.
  ///
  /// Only single-sheet workbooks are supported as CSV does not support
  /// multi-sheet data.
  Future<void> saveToCsv({
    required Workbook workbook,
    required File file,
    String fieldDelimiter = ',',
    String eol = '\n',
  }) async {
    if (workbook.sheets.length != 1) {
      throw ArgumentError(
        'CSV serialisation expects a workbook with exactly one sheet.',
      );
    }

    final sheet = workbook.sheets.first;
    final table = sheet.rows
        .map(
          (row) => row
              .map(
                (cell) => _cellFactory.toField(cell),
              )
              .toList(growable: false),
        )
        .toList(growable: false);

    final converter = const ListToCsvConverter();
    final csv = converter.convert(
      table,
      fieldDelimiter: fieldDelimiter,
      eol: eol,
    );

    await file.writeAsString(csv);
  }
}
