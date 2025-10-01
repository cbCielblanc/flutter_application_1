import '../../domain/cell.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

class InsertColumnCommand extends WorkbookCommand {
  InsertColumnCommand({this.columnIndex});

  final int? columnIndex;

  @override
  String get label => 'Insérer une colonne';

  @override
  bool canExecute(WorkbookCommandContext context) {
    return context.activeSheet != null;
  }

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    final sheet = context.activeSheet;
    if (sheet == null) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final rows = cloneSheetRows(sheet);
    final existingColumnCount = sheet.columnCount;
    final desiredIndex = columnIndex ?? existingColumnCount;
    final insertIndex = desiredIndex < 0
        ? 0
        : desiredIndex > existingColumnCount
            ? existingColumnCount
            : desiredIndex;

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      row.insert(
        insertIndex,
        Cell(row: r, column: insertIndex, type: CellType.empty, value: null),
      );
    }

    final normalisedRows = normaliseCellCoordinates(rows);
    final updatedSheet = rebuildSheetFromRows(sheet, normalisedRows);
    final Workbook updatedWorkbook =
        replaceSheet(context.workbook, context.activeSheetIndex, updatedSheet);

    return WorkbookCommandResult(workbook: updatedWorkbook);
  }
}
