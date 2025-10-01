import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

class UppercaseHeaderCommand extends WorkbookCommand {
  const UppercaseHeaderCommand();

  @override
  String get label => 'Entêtes en majuscules';

  @override
  bool canExecute(WorkbookCommandContext context) {
    final sheet = context.activeSheet;
    return sheet != null && sheet.rowCount > 0 && sheet.columnCount > 0;
  }

  @override
  WorkbookCommandResult execute(WorkbookCommandContext context) {
    final sheet = context.activeSheet;
    if (sheet == null || sheet.rowCount == 0) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final rows = cloneSheetRows(sheet);
    final headerRow = rows.first;
    for (var c = 0; c < headerRow.length; c++) {
      final cell = headerRow[c];
      if (cell.type == CellType.text) {
        headerRow[c] = Cell(
          row: 0,
          column: c,
          type: CellType.text,
          value: (cell.value as String).toUpperCase(),
        );
      }
    }

    final updatedSheet = rebuildSheetFromRows(sheet, rows);
    final Workbook updatedWorkbook =
        replaceSheet(context.workbook, context.activeSheetIndex, updatedSheet);

    return WorkbookCommandResult(workbook: updatedWorkbook);
  }
}
