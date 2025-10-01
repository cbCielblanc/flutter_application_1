import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

class InsertRowCommand extends WorkbookCommand {
  const InsertRowCommand({this.rowIndex});

  final int? rowIndex;

  @override
  String get label => 'Insérer une ligne';

  @override
  bool canExecute(WorkbookCommandContext context) {
    final sheet = context.activeSheet;
    return sheet != null;
  }

  @override
  WorkbookCommandResult execute(WorkbookCommandContext context) {
    final sheet = context.activeSheet;
    if (sheet == null) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final rows = cloneSheetRows(sheet);
    final desiredIndex = rowIndex ?? rows.length;
    final insertIndex = desiredIndex < 0
        ? 0
        : desiredIndex > rows.length
            ? rows.length
            : desiredIndex;
    final newRow = buildEmptyRow(insertIndex, sheet.columnCount);
    rows.insert(insertIndex, newRow);
    final normalisedRows = normaliseCellCoordinates(rows);

    final updatedSheet = rebuildSheetFromRows(sheet, normalisedRows);
    final Workbook updatedWorkbook =
        replaceSheet(context.workbook, context.activeSheetIndex, updatedSheet);

    return WorkbookCommandResult(workbook: updatedWorkbook);
  }
}
