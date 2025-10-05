import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

/// Commande permettant de modifier la valeur d'une cellule spécifique.
class SetCellValueCommand extends WorkbookCommand {
  SetCellValueCommand({
    required this.sheetName,
    required this.row,
    required this.column,
    this.value,
  });

  /// Nom de la feuille ciblée.
  final String sheetName;

  /// Index de ligne (base zéro).
  final int row;

  /// Index de colonne (base zéro).
  final int column;

  /// Valeur à appliquer à la cellule.
  final Object? value;

  @override
  String get label => 'Mettre à jour une cellule';

  @override
  bool canExecute(WorkbookCommandContext context) {
    if (row < 0 || column < 0) {
      return false;
    }
    final sheet = _resolveSheet(context.workbook);
    if (sheet == null) {
      return false;
    }
    if (row >= sheet.rowCount || column >= sheet.columnCount) {
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
    final nextCell = _buildCell();
    final currentCell = rows[row][column];

    if (currentCell.type == nextCell.type && currentCell.value == nextCell.value) {
      return WorkbookCommandResult(
        workbook: context.workbook,
        activePageIndex: context.activePageIndex,
      );
    }

    rows[row][column] = nextCell;
    final normalisedRows = normaliseCellCoordinates(rows);
    final updatedSheet = rebuildSheetFromRows(sheet, normalisedRows);
    final Workbook updatedWorkbook = replaceSheetAtPageIndex(
      context.workbook,
      pageIndex,
      updatedSheet,
    );

    return WorkbookCommandResult(
      workbook: updatedWorkbook,
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

  Cell _buildCell() {
    final normalisedValue = value;
    if (normalisedValue == null ||
        (normalisedValue is String && normalisedValue.isEmpty)) {
      return Cell(row: row, column: column, type: CellType.empty, value: null);
    }
    return Cell.fromValue(
      row: row,
      column: column,
      value: normalisedValue,
    );
  }
}
