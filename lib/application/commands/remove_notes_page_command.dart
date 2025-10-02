import '../../domain/notes_page.dart';
import '../../domain/workbook.dart';
import 'workbook_command.dart';

class RemoveNotesPageCommand extends WorkbookCommand {
  RemoveNotesPageCommand({required this.pageIndex});

  final int pageIndex;

  @override
  String get label => 'Supprimer la page de notes';

  @override
  bool canExecute(WorkbookCommandContext context) {
    if (pageIndex < 0 || pageIndex >= context.workbook.pages.length) {
      return false;
    }
    final page = context.workbook.pages[pageIndex];
    return page is NotesPage;
  }

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    if (!canExecute(context)) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final pages = context.workbook.pages.toList(growable: true);
    pages.removeAt(pageIndex);
    final updatedWorkbook = Workbook(pages: pages);
    final newActiveIndex = pageIndex >= pages.length ? pages.length - 1 : pageIndex;

    return WorkbookCommandResult(
      workbook: updatedWorkbook,
      activePageIndex: newActiveIndex < 0 ? 0 : newActiveIndex,
    );
  }
}
