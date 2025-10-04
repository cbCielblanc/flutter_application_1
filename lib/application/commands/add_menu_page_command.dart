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
  String get label => 'Créer le menu principal';

  @override
  bool canExecute(WorkbookCommandContext context) {
    final menuCount = context.workbook.pages.whereType<MenuPage>().length;
    return menuCount < 1;
  }

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    final initialMetadata = Map<String, Object?>.from(metadata);
    final tree = layout == 'tree'
        ? _resolveTree(initialMetadata, context.workbook)
        : null;
    if (tree != null) {
      initialMetadata['tree'] = tree.toMetadata();
    }

    final newPage = MenuPage(
      name: _generatePageName(context.workbook),
      layout: layout,
      metadata: initialMetadata,
      tree: tree,
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

  String _generatePageName(Workbook workbook) => 'Menu principal';

  MenuTree? _resolveTree(
    Map<String, Object?> metadata,
    Workbook workbook,
  ) {
    if (metadata.containsKey('tree')) {
      final parsed = MenuTree.fromMetadata(metadata['tree']);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    final generated = MenuTree.fromWorkbookPages(workbook.pages);
    return generated.isEmpty ? null : generated;
  }
}
