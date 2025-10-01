import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'workbook_command.dart';

class AddSheetCommand extends WorkbookCommand {
  AddSheetCommand({this.rowCount = 20, this.columnCount = 8});

  final int rowCount;
  final int columnCount;

  @override
  String get label => 'Nouvelle feuille';

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    final newSheetName = _generateSheetName(context.workbook);
    final rows = List<List<Cell>>.generate(
      rowCount,
      (row) => List<Cell>.generate(
        columnCount,
        (column) =>
            Cell(row: row, column: column, type: CellType.empty, value: null),
      ),
      growable: false,
    );

    final newSheet = Sheet(name: newSheetName, rows: rows);
    final pages = context.workbook.pages.toList(growable: true)..add(newSheet);
    final updatedWorkbook = Workbook(pages: pages);
    final newIndex = updatedWorkbook.pages.indexOf(newSheet);
    assert(newIndex != -1, 'Newly added sheet must be present in workbook.');

    return WorkbookCommandResult(
      workbook: updatedWorkbook,
      activePageIndex: newIndex,
    );
  }

  String _generateSheetName(Workbook workbook) {
    const prefix = 'Feuille ';
    var highest = 0;
    for (final sheet in workbook.sheets) {
      if (sheet.name.startsWith(prefix)) {
        final maybeNumber = int.tryParse(sheet.name.substring(prefix.length));
        if (maybeNumber != null && maybeNumber > highest) {
          highest = maybeNumber;
        }
      }
    }
    return '$prefix${highest + 1}';
  }
}
