import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

/// Commande permettant d'écrire un bloc de valeurs dans une plage rectangulaire.
class SetRangeValuesCommand extends WorkbookCommand {
  SetRangeValuesCommand({
    required this.sheetName,
    required this.startRow,
    required this.startColumn,
    required this.values,
  }) : assert(values.isNotEmpty, 'values must not be empty'),
        assert(values.every((row) => row.length == values.first.length),
            'All value rows must share the same length.');

  /// Nom de la feuille ciblée.
  final String sheetName;

  /// Index de ligne de départ (base zéro).
  final int startRow;

  /// Index de colonne de départ (base zéro).
  final int startColumn;

  /// Valeurs à appliquer.
  final List<List<Object?>> values;

  int get rowCount => values.length;
  int get columnCount => values.first.length;

  @override
  String get label => 'Mettre à jour une plage';

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
        final newCell = _buildCell(targetRow, targetColumn, values[r][c]);
        final current = rows[targetRow][targetColumn];
        if (current.type == newCell.type && current.value == newCell.value) {
          continue;
        }
        rows[targetRow][targetColumn] = newCell;
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

  Cell _buildCell(int row, int column, Object? value) {
    if (value == null || (value is String && value.isEmpty)) {
      return Cell(row: row, column: column, type: CellType.empty, value: null);
    }
    return Cell.fromValue(row: row, column: column, value: value);
  }
}
