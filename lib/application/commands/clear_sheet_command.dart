import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

class ClearSheetCommand extends WorkbookCommand {
  ClearSheetCommand();

  @override
  String get label => 'Effacer les données';

  @override
  bool canExecute(WorkbookCommandContext context) {
    final sheet = context.activeSheet;
    return sheet != null && sheet.rowCount > 0 && sheet.columnCount > 0;
  }

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    final sheet = context.activeSheet;
    if (sheet == null) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final rows = cloneSheetRows(sheet);
    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      for (var c = 0; c < row.length; c++) {
        row[c] = Cell(row: r, column: c, type: CellType.empty, value: null);
      }
    }

    final updatedSheet = rebuildSheetFromRows(sheet, rows);
    final Workbook updatedWorkbook =
        replaceSheet(context.workbook, context.activeSheetIndex, updatedSheet);

    return WorkbookCommandResult(workbook: updatedWorkbook);
  }
}
