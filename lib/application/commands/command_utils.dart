import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';

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
Workbook replaceSheet(Workbook workbook, int sheetIndex, Sheet newSheet) {
  final target = workbook.sheets[sheetIndex];
  final pages = workbook.pages.toList(growable: true);
  final pageIndex = pages.indexOf(target);
  assert(pageIndex != -1, 'Sheet must exist in workbook pages.');
  pages[pageIndex] = newSheet;
  return Workbook(pages: pages);
}

Sheet rebuildSheetFromRows(Sheet template, List<List<Cell>> rows) {
  return Sheet(name: template.name, rows: rows);
}
