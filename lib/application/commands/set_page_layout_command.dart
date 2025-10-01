import '../../domain/menu_page.dart';
import 'command_utils.dart';
import 'workbook_command.dart';

class SetPageLayoutCommand extends WorkbookCommand {
  SetPageLayoutCommand({
    required this.layout,
    this.pageIndex,
  });

  final String layout;
  final int? pageIndex;

  @override
  String get label => 'Définir la mise en page';

  int? _resolvePageIndex(WorkbookCommandContext context) {
    if (pageIndex != null) {
      if (pageIndex! < 0 || pageIndex! >= context.workbook.pages.length) {
        return null;
      }
      return pageIndex;
    }
    if (!context.hasPages) {
      return null;
    }
    return context.activePageIndex;
  }

  @override
  bool canExecute(WorkbookCommandContext context) {
    final targetIndex = _resolvePageIndex(context);
    if (targetIndex == null) {
      return false;
    }
    final page = context.workbook.pages[targetIndex];
    return page is MenuPage;
  }

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    final targetIndex = _resolvePageIndex(context);
    if (targetIndex == null) {
      return WorkbookCommandResult(workbook: context.workbook);
    }
    final page = context.workbook.pages[targetIndex];
    if (page is! MenuPage) {
      return WorkbookCommandResult(workbook: context.workbook);
    }

    final updatedPage = page.copyWith(layout: layout);
    final updatedWorkbook = replacePage(
      context.workbook,
      targetIndex,
      updatedPage,
    );

    return WorkbookCommandResult(
      workbook: updatedWorkbook,
      activePageIndex: context.activePageIndex,
    );
  }
}
