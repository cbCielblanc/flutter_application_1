import '../../domain/notes_page.dart';
import '../../domain/workbook.dart';
import 'workbook_command.dart';

class AddNotesPageCommand extends WorkbookCommand {
  AddNotesPageCommand({
    String initialContent = '',
    Map<String, Object?> metadata = const {},
  })  : _initialContent = initialContent,
        _metadata = Map<String, Object?>.unmodifiable(metadata);

  final String _initialContent;
  final Map<String, Object?> _metadata;

  @override
  String get label => 'Nouvelle page de notes';

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    final pageName = _generatePageName(context.workbook);
    final newPage = NotesPage(
      name: pageName,
      content: _initialContent,
      metadata: _metadata,
    );
    final pages = context.workbook.pages.toList(growable: true)..add(newPage);
    final updatedWorkbook = Workbook(pages: pages);
    final newIndex = updatedWorkbook.pages.indexOf(newPage);
    assert(
      newIndex != -1,
      'Newly added notes page must be present in workbook.',
    );

    return WorkbookCommandResult(
      workbook: updatedWorkbook,
      activePageIndex: newIndex,
    );
  }

  String _generatePageName(Workbook workbook) {
    const prefix = 'Notes ';
    var highest = 0;
    for (final page in workbook.pages.whereType<NotesPage>()) {
      if (page.name.startsWith(prefix)) {
        final maybeNumber = int.tryParse(page.name.substring(prefix.length));
        if (maybeNumber != null && maybeNumber > highest) {
          highest = maybeNumber;
        }
      }
    }
    final candidate = '$prefix${highest + 1}';
    if (workbook.pages.any((page) => page.name == candidate)) {
      var suffix = highest + 2;
      while (workbook.pages.any((page) => page.name == '$prefix$suffix')) {
        suffix++;
      }
      return '$prefix$suffix';
    }
    return candidate;
  }
}
