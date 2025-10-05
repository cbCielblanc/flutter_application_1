import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

enum RangeFillDirection { down, right }

/// Commande permettant de recopier automatiquement des valeurs sur une plage.
class AutoFillRangeCommand extends WorkbookCommand {
  AutoFillRangeCommand({
    required this.sheetName,
    required this.startRow,
    required this.startColumn,
    required this.rowCount,
    required this.columnCount,
    this.direction = RangeFillDirection.down,
  })  : assert(rowCount > 0, 'rowCount must be > 0'),
        assert(columnCount > 0, 'columnCount must be > 0');

  final String sheetName;
  final int startRow;
  final int startColumn;
  final int rowCount;
  final int columnCount;
  final RangeFillDirection direction;

  @override
  String get label => 'Remplissage automatique';

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

    switch (direction) {
      case RangeFillDirection.down:
        for (var c = 0; c < columnCount; c++) {
          final template = rows[startRow][startColumn + c];
          for (var r = 1; r < rowCount; r++) {
            final targetRow = startRow + r;
            final current = rows[targetRow][startColumn + c];
            if (current.type == template.type && current.value == template.value) {
              continue;
            }
            rows[targetRow][startColumn + c] = Cell(
              row: targetRow,
              column: startColumn + c,
              type: template.type,
              value: template.value,
            );
            changed = true;
          }
        }
        break;
      case RangeFillDirection.right:
        for (var r = 0; r < rowCount; r++) {
          final template = rows[startRow + r][startColumn];
          for (var c = 1; c < columnCount; c++) {
            final targetColumn = startColumn + c;
            final current = rows[startRow + r][targetColumn];
            if (current.type == template.type && current.value == template.value) {
              continue;
            }
            rows[startRow + r][targetColumn] = Cell(
              row: startRow + r,
              column: targetColumn,
              type: template.type,
              value: template.value,
            );
            changed = true;
          }
        }
        break;
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
