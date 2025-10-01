import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import 'workbook_command.dart';

class AddSheetCommand extends WorkbookCommand {
  const AddSheetCommand({this.rowCount = 20, this.columnCount = 8});

  final int rowCount;
  final int columnCount;

  @override
  String get label => 'Nouvelle feuille';

  @override
  WorkbookCommandResult execute(WorkbookCommandContext context) {
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
    final sheets = context.workbook.sheets.toList(growable: true)..add(newSheet);
    final updatedWorkbook = Workbook(sheets: sheets);
    final newIndex = sheets.length - 1;

    return WorkbookCommandResult(
      workbook: updatedWorkbook,
      activeSheetIndex: newIndex,
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
