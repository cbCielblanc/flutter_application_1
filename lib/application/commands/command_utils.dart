import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import '../../domain/workbook_page.dart';

List<List<Cell>> cloneSheetRows(Sheet sheet) {
  final sourceRows = sheet.rows;
  final rows = List<List<Cell>>.generate(
    sourceRows.length,
    (r) {
      final row = sourceRows[r];
      return [
        for (var c = 0; c < row.length; c++)
          Cell(row: r, column: c, type: row[c].type, value: row[c].value)
      ];
    },
    growable: true,
  );
  return rows;
}

List<Cell> buildEmptyRow(int rowIndex, int columnCount) {
  return List<Cell>.generate(
    columnCount,
    (column) =>
        Cell(row: rowIndex, column: column, type: CellType.empty, value: null),
  );
}

List<List<Cell>> normaliseCellCoordinates(List<List<Cell>> rows) {
  for (var r = 0; r < rows.length; r++) {
    final row = rows[r];
    for (var c = 0; c < row.length; c++) {
      final cell = row[c];
      if (cell.row != r || cell.column != c) {
        row[c] = Cell(row: r, column: c, type: cell.type, value: cell.value);
      }
    }
  }
  return rows;
}
Workbook replacePage(
  Workbook workbook,
  int pageIndex,
  WorkbookPage newPage,
) {
  if (pageIndex < 0 || pageIndex >= workbook.pages.length) {
    throw RangeError.index(pageIndex, workbook.pages, 'pageIndex');
  }
  final pages = workbook.pages.toList(growable: true);
  pages[pageIndex] = newPage;
  return Workbook(pages: pages);
}

Workbook replaceSheetAtPageIndex(
  Workbook workbook,
  int pageIndex,
  Sheet newSheet,
) {
  final page = workbook.pages[pageIndex];
  if (page is! Sheet) {
    throw StateError('The page at index $pageIndex is not a Sheet.');
  }
  return replacePage(workbook, pageIndex, newSheet);
}

Sheet rebuildSheetFromRows(Sheet template, List<List<Cell>> rows) {
  return Sheet(name: template.name, rows: rows);
}
