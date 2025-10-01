import 'package:meta/meta.dart';

import 'sheet.dart';
import 'workbook_page.dart';

/// Represents a spreadsheet workbook.
///
/// Invariants:
/// * Page names are unique.
/// * A workbook exposes at least one page to remain meaningful.
@immutable
class Workbook {
  Workbook({
    required List<WorkbookPage> pages,
  })  : assert(pages.isNotEmpty, 'A workbook must contain at least one page.'),
        assert(
          _arePageNamesUnique(pages),
          'Page names must be unique.',
        ),
        _pages = List<WorkbookPage>.unmodifiable(pages);

  final List<WorkbookPage> _pages;

  /// Immutable view on the pages.
  List<WorkbookPage> get pages => _pages;

  /// Convenience view limited to [Sheet] pages.
  List<Sheet> get sheets =>
      List<Sheet>.unmodifiable(_pages.whereType<Sheet>());

  /// Serialises the workbook to CSV per sheet.
  ///
  /// Each entry in the resulting map uses the sheet name as key and the CSV
  /// representation as value. Consumers can persist the map or recombine the
  /// values into archive formats (zip, etc.).
  Map<String, String> toCsvMap({String fieldDelimiter = ',', String eol = '\n'}) {
    return {
      for (final page in _pages)
        if (page is Sheet)
          page.name: page.toCsv(fieldDelimiter: fieldDelimiter, eol: eol),
    };
  }

  /// Builds a workbook from CSV chunks.
  factory Workbook.fromCsvMap(Map<String, String> csvSheets) {
    if (csvSheets.isEmpty) {
      throw const FormatException('A workbook must contain at least one sheet.');
    }

    final pages = csvSheets.entries
        .map<WorkbookPage>(
          (entry) => Sheet.fromCsv(name: entry.key, csv: entry.value),
        )
        .toList(growable: false);

    return Workbook(pages: pages);
  }

  static bool _arePageNamesUnique(List<WorkbookPage> pages) {
    final seen = <String>{};
    for (final page in pages) {
      if (!seen.add(page.name)) {
        return false;
      }
    }
    return true;
  }
}
