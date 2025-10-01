import '../../domain/menu_page.dart';
import '../../domain/workbook.dart';
import 'workbook_command.dart';

class AddMenuPageCommand extends WorkbookCommand {
  AddMenuPageCommand({
    this.layout = 'list',
    Map<String, Object?> metadata = const {},
  }) : metadata = Map<String, Object?>.unmodifiable(metadata);

  final String layout;
  final Map<String, Object?> metadata;

  @override
  String get label => 'Nouvelle page menu';

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    final newPageName = _generatePageName(context.workbook);
    final newPage = MenuPage(
      name: newPageName,
      layout: layout,
      metadata: metadata,
    );
    final pages = context.workbook.pages.toList(growable: true)..add(newPage);
    final updatedWorkbook = Workbook(pages: pages);
    final newIndex = updatedWorkbook.pages.indexOf(newPage);
    assert(newIndex != -1, 'Newly added menu page must be present in workbook.');

    return WorkbookCommandResult(
      workbook: updatedWorkbook,
      activePageIndex: newIndex,
    );
  }

  String _generatePageName(Workbook workbook) {
    const prefix = 'Menu ';
    var highest = 0;
    for (final page in workbook.pages.whereType<MenuPage>()) {
      if (page.name.startsWith(prefix)) {
        final maybeNumber = int.tryParse(page.name.substring(prefix.length));
        if (maybeNumber != null && maybeNumber > highest) {
          highest = maybeNumber;
        }
      }
    }
    return '$prefix${highest + 1}';
  }
}
