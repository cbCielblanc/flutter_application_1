import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

class PopulateSampleDataCommand extends WorkbookCommand {
  PopulateSampleDataCommand();

  @override
  String get label => 'Données d\'exemple';

  @override
  bool canExecute(WorkbookCommandContext context) {
    final sheet = context.activeSheet;
    return sheet != null && sheet.columnCount > 0;
  }

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    final sheet = context.activeSheet;
    if (sheet == null) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final pageIndex = context.pageIndexOf(sheet);
    if (pageIndex == null) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    const sample = <List<Object?>>[
      ['Nom', 'Âge', 'Ville', 'Profession'],
      ['Alice', 29, 'Paris', 'Designer'],
      ['Bob', 35, 'Lyon', 'Développeur'],
    ];

    final rows = cloneSheetRows(sheet);
    final requiredRows = sample.length;
    final columnCount = sheet.columnCount;

    while (rows.length < requiredRows) {
      rows.add(buildEmptyRow(rows.length, columnCount));
    }

    for (var r = 0; r < sample.length; r++) {
      final row = rows[r];
      final dataRow = sample[r];
      final limit = dataRow.length < row.length ? dataRow.length : row.length;
      for (var c = 0; c < limit; c++) {
        row[c] = Cell.fromValue(row: r, column: c, value: dataRow[c]);
      }
    }

    final updatedSheet = rebuildSheetFromRows(sheet, rows);
    final Workbook updatedWorkbook =
        replaceSheetAtPageIndex(context.workbook, pageIndex, updatedSheet);

    return WorkbookCommandResult(
      workbook: updatedWorkbook,
      activePageIndex: context.activePageIndex,
    );
  }
}
