import '../../domain/workbook.dart';
import 'workbook_command.dart';

class RemoveSheetCommand extends WorkbookCommand {
  const RemoveSheetCommand({this.sheetIndex});

  final int? sheetIndex;

  const RemoveSheetCommand.forIndex(int index) : sheetIndex = index;

  @override
  String get label => 'Supprimer la feuille';

  @override
  bool canExecute(WorkbookCommandContext context) {
    final index = sheetIndex ?? context.activeSheetIndex;
    return context.workbook.sheets.length > 1 &&
        index >= 0 &&
        index < context.workbook.sheets.length;
  }

  @override
  WorkbookCommandResult execute(WorkbookCommandContext context) {
    final index = sheetIndex ?? context.activeSheetIndex;
    if (!canExecute(context)) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final sheets = context.workbook.sheets.toList(growable: true)
      ..removeAt(index);
    final updatedWorkbook = Workbook(sheets: sheets);

    final newActiveIndex = index.clamp(0, sheets.length - 1);

    return WorkbookCommandResult(
      workbook: updatedWorkbook,
      activeSheetIndex: newActiveIndex,
    );
  }
}
