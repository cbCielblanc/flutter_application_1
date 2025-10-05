import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

/// Commande triant les lignes d'une plage suivant une colonne de référence.
class SortRangeCommand extends WorkbookCommand {
  SortRangeCommand({
    required this.sheetName,
    required this.startRow,
    required this.startColumn,
    required this.rowCount,
    required this.columnCount,
    this.columnOffset = 0,
    this.ascending = true,
  })  : assert(rowCount > 0, 'rowCount must be > 0'),
        assert(columnCount > 0, 'columnCount must be > 0'),
        assert(columnOffset >= 0, 'columnOffset must be >= 0');

  final String sheetName;
  final int startRow;
  final int startColumn;
  final int rowCount;
  final int columnCount;
  final int columnOffset;
  final bool ascending;

  @override
  String get label => 'Tri de plage';

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
    if (columnOffset >= columnCount) {
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
    final segment = <List<Cell>>[for (var r = 0; r < rowCount; r++) []];

    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < columnCount; c++) {
        segment[r].add(rows[startRow + r][startColumn + c]);
      }
    }

    final sorted = List<List<Cell>>.from(segment);
    sorted.sort((a, b) {
      final left = a[columnOffset];
      final right = b[columnOffset];
      final order = _compareCells(left, right);
      return ascending ? order : -order;
    });

    var changed = false;
    for (var r = 0; r < rowCount; r++) {
      for (var c = 0; c < columnCount; c++) {
        final targetRow = startRow + r;
        final targetColumn = startColumn + c;
        final current = rows[targetRow][targetColumn];
        final next = sorted[r][c];
        if (current.type == next.type && current.value == next.value) {
          continue;
        }
        rows[targetRow][targetColumn] = Cell(
          row: targetRow,
          column: targetColumn,
          type: next.type,
          value: next.value,
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

  int _compareCells(Cell left, Cell right) {
    if (left.type == CellType.empty && right.type == CellType.empty) {
      return 0;
    }
    if (left.type == CellType.empty) {
      return 1;
    }
    if (right.type == CellType.empty) {
      return -1;
    }
    if (left.type == CellType.number && right.type == CellType.number) {
      final lv = (left.value as num).toDouble();
      final rv = (right.value as num).toDouble();
      return lv.compareTo(rv);
    }
    if (left.type == CellType.boolean && right.type == CellType.boolean) {
      return (left.value as bool).toString().compareTo((right.value as bool).toString());
    }
    return left.value.toString().compareTo(right.value.toString());
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
