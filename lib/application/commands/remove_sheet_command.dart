import '../../domain/workbook.dart';
import 'workbook_command.dart';

class RemoveSheetCommand extends WorkbookCommand {
  RemoveSheetCommand({this.sheetIndex});

  final int? sheetIndex;

  RemoveSheetCommand.forIndex(int index) : sheetIndex = index;

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
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    final index = sheetIndex ?? context.activeSheetIndex;
    if (!canExecute(context)) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final sheet = context.workbook.sheets[index];
    final pages = context.workbook.pages.toList(growable: true);
    final pageIndex = pages.indexOf(sheet);
    assert(pageIndex != -1, 'Sheet must exist in workbook pages.');
    pages.removeAt(pageIndex);
    final updatedWorkbook = Workbook(pages: pages);

    final newActiveIndex = index.clamp(0, updatedWorkbook.sheets.length - 1);

    return WorkbookCommandResult(
      workbook: updatedWorkbook,
      activeSheetIndex: newActiveIndex,
    );
  }
}
