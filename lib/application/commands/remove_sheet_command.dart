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
    if (context.workbook.pages.length <= 1) {
      return false;
    }
    final index = sheetIndex ?? context.activeSheetIndex;
    return index != null &&
        index >= 0 &&
        index < context.workbook.sheets.length;
  }

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    final tabIndex = sheetIndex ?? context.activeSheetIndex;
    if (tabIndex == null) {
      return WorkbookCommandResult(workbook: context.workbook);
    }
    if (!canExecute(context)) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final sheet = context.workbook.sheets[tabIndex];
    final pages = context.workbook.pages.toList(growable: true);
    final pageIndex = pages.indexOf(sheet);
    assert(pageIndex != -1, 'Sheet must exist in workbook pages.');
    pages.removeAt(pageIndex);
    final updatedWorkbook = Workbook(pages: pages);

    final maxIndex = updatedWorkbook.pages.length - 1;
    final newActiveIndex = pageIndex > maxIndex ? maxIndex : pageIndex;

    return WorkbookCommandResult(
      workbook: updatedWorkbook,
      activePageIndex: newActiveIndex,
    );
  }
}
