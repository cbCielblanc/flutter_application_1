import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

class InsertRowCommand extends WorkbookCommand {
  const InsertRowCommand();

  @override
  String get label => 'Insérer une ligne';

  @override
  bool canExecute(WorkbookCommandContext context) {
    final sheet = context.activeSheet;
    return sheet != null && sheet.columnCount > 0;
  }

  @override
  WorkbookCommandResult execute(WorkbookCommandContext context) {
    final sheet = context.activeSheet;
    if (sheet == null || sheet.columnCount == 0) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final rows = cloneSheetRows(sheet);
    final newRowIndex = rows.length;
    rows.add(buildEmptyRow(newRowIndex, sheet.columnCount));

    final updatedSheet = rebuildSheetFromRows(sheet, rows);
    final Workbook updatedWorkbook =
        replaceSheet(context.workbook, context.activeSheetIndex, updatedSheet);

    return WorkbookCommandResult(workbook: updatedWorkbook);
  }
}
