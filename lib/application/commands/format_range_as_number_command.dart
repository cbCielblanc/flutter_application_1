import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

/// Commande appliquant un format numérique à une plage.
class FormatRangeAsNumberCommand extends WorkbookCommand {
  FormatRangeAsNumberCommand({
    required this.sheetName,
    required this.startRow,
    required this.startColumn,
    required this.rowCount,
    required this.columnCount,
    this.decimalDigits,
  })  : assert(rowCount > 0, 'rowCount must be > 0'),
        assert(columnCount > 0, 'columnCount must be > 0'),
        assert(decimalDigits == null || decimalDigits >= 0,
            'decimalDigits must be >= 0');

  final String sheetName;
  final int startRow;
  final int startColumn;
  final int rowCount;
  final int columnCount;
  final int? decimalDigits;

  @override
  String get label => 'Format numérique de plage';

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
        final formatted = _formatCell(targetRow, targetColumn, current);
        if (formatted == null) {
          continue;
        }
        if (current.type == formatted.type && current.value == formatted.value) {
          continue;
        }
        rows[targetRow][targetColumn] = formatted;
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

  Cell? _formatCell(int row, int column, Cell current) {
    if (current.type == CellType.empty) {
      return null;
    }
    final asNumber = switch (current.type) {
      CellType.number => current.value as num,
      CellType.text => num.tryParse(current.value.toString()),
      CellType.boolean => null,
      CellType.empty => null,
    };
    if (asNumber == null) {
      return null;
    }

    final num value;
    if (decimalDigits != null) {
      final precision = decimalDigits!.clamp(0, 15);
      value = num.parse(asNumber.toStringAsFixed(precision));
    } else {
      value = asNumber;
    }

    return Cell(row: row, column: column, type: CellType.number, value: value);
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
