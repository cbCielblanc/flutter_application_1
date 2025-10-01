import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';

List<List<Cell>> cloneSheetRows(Sheet sheet) {
  final rows = <List<Cell>>[];
  for (var r = 0; r < sheet.rows.length; r++) {
    final row = sheet.rows[r];
    rows.add([
      for (var c = 0; c < row.length; c++)
        Cell(row: r, column: c, type: row[c].type, value: row[c].value)
    ]);
  }
  return rows;
}

List<Cell> buildEmptyRow(int rowIndex, int columnCount) {
  return List<Cell>.generate(
    columnCount,
    (column) =>
        Cell(row: rowIndex, column: column, type: CellType.empty, value: null),
  );
}

Workbook replaceSheet(Workbook workbook, int sheetIndex, Sheet newSheet) {
  final sheets = workbook.sheets.toList(growable: true);
  sheets[sheetIndex] = newSheet;
  return Workbook(sheets: sheets);
}

Sheet rebuildSheetFromRows(Sheet template, List<List<Cell>> rows) {
  return Sheet(name: template.name, rows: rows);
}
