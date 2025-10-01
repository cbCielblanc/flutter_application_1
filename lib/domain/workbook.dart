import 'package:meta/meta.dart';

import 'sheet.dart';

/// Represents a spreadsheet workbook.
///
/// Invariants:
/// * Sheet names are unique.
/// * A workbook exposes at least one sheet to remain meaningful.
@immutable
class Workbook {
  Workbook({
    required List<Sheet> sheets,
  })  : assert(sheets.isNotEmpty, 'A workbook must contain at least one sheet.'),
        assert(
          _areSheetNamesUnique(sheets),
          'Sheet names must be unique.',
        ),
        _sheets = List<Sheet>.unmodifiable(sheets);

  final List<Sheet> _sheets;

  /// Immutable view on the sheets.
  List<Sheet> get sheets => _sheets;

  /// Serialises the workbook to CSV per sheet.
  ///
  /// Each entry in the resulting map uses the sheet name as key and the CSV
  /// representation as value. Consumers can persist the map or recombine the
  /// values into archive formats (zip, etc.).
  Map<String, String> toCsvMap({String fieldDelimiter = ',', String eol = '\n'}) {
    return {
      for (final sheet in _sheets)
        sheet.name: sheet.toCsv(fieldDelimiter: fieldDelimiter, eol: eol),
    };
  }

  /// Builds a workbook from CSV chunks.
  factory Workbook.fromCsvMap(Map<String, String> csvSheets) {
    if (csvSheets.isEmpty) {
      throw const FormatException('A workbook must contain at least one sheet.');
    }

    final sheets = csvSheets.entries
        .map(
          (entry) => Sheet.fromCsv(name: entry.key, csv: entry.value),
        )
        .toList(growable: false);

    return Workbook(sheets: sheets);
  }

  static bool _areSheetNamesUnique(List<Sheet> sheets) {
    final seen = <String>{};
    for (final sheet in sheets) {
      if (!seen.add(sheet.name)) {
        return false;
      }
    }
    return true;
  }
}
