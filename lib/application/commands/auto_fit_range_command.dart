import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

/// Commande simulant un auto-fit en nettoyant les contenus textuels d'une plage.
class AutoFitRangeCommand extends WorkbookCommand {
  AutoFitRangeCommand({
    required this.sheetName,
    required this.startRow,
    required this.startColumn,
    required this.rowCount,
    required this.columnCount,
  })  : assert(rowCount > 0, 'rowCount must be > 0'),
        assert(columnCount > 0, 'columnCount must be > 0');

  final String sheetName;
  final int startRow;
  final int startColumn;
  final int rowCount;
  final int columnCount;

  @override
  String get label => 'Auto-fit plage';

  @override
  bool canExecute(WorkbookCommandContext context) {
    if (startRow < 0 || startColumn < 0) {
      return false;
    }
    final sheet = _resolveSheet(context.workbook);
    if (sheet == null) {
      return false;
    }
    if (startRow + rowCount > sheet.rowCount) {
      return false;
    }
    if (startColumn + columnCount > sheet.columnCount) {
      return false;
    }
    return true;
  }

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    final sheet = _resolveSheet(context.workbook);
    if (sheet == null) {
      return WorkbookCommandResult(workbook: context.workbook);
    }
    final pageIndex = context.pageIndexOf(sheet);
    if (pageIndex == null) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final rows = cloneSheetRows(sheet);
    var changed = false;
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < columnCount; c++) {
        final targetRow = startRow + r;
        final targetColumn = startColumn + c;
        final current = rows[targetRow][targetColumn];
        if (current.type != CellType.text) {
          continue;
        }
        final trimmed = current.value?.toString().trim();
        if (trimmed == current.value) {
          continue;
        }
        rows[targetRow][targetColumn] = Cell(
          row: targetRow,
          column: targetColumn,
          type: trimmed == null || trimmed.isEmpty
              ? CellType.empty
              : CellType.text,
          value: trimmed == null || trimmed.isEmpty ? null : trimmed,
        );
        changed = true;
      }
    }

    if (!changed) {
      return WorkbookCommandResult(
        workbook: context.workbook,
        activePageIndex: context.activePageIndex,
      );
    }

    final normalisedRows = normaliseCellCoordinates(rows);
    final updatedSheet = rebuildSheetFromRows(sheet, normalisedRows);
    final workbook = replaceSheetAtPageIndex(
      context.workbook,
      pageIndex,
      updatedSheet,
    );

    return WorkbookCommandResult(
      workbook: workbook,
      activePageIndex: context.activePageIndex,
    );
  }

  Sheet? _resolveSheet(Workbook workbook) {
    for (final sheet in workbook.sheets) {
      if (sheet.name == sheetName) {
        return sheet;
      }
    }
    return null;
  }
}
