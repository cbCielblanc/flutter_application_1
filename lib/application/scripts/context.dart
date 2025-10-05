import 'dart:async';

import '../../domain/menu_page.dart';
import '../../domain/notes_page.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import '../../domain/workbook_page.dart';
import '../../state/sheet_selection_state.dart';
import '../commands/workbook_command_manager.dart';
import 'api/api.dart';
import 'models.dart';
import 'navigator_binding.dart';
import 'scope.dart';

typedef ScriptContextLog = FutureOr<void> Function(String message);

class ScriptContext {
  ScriptContext({
    required this.descriptor,
    required this.eventType,
    required this.workbook,
    required this.commandManager,
    required this.log,
    this.page,
    this.sheet,
    this.navigatorBinding,
    Map<String, Object?> additional = const <String, Object?>{},
  })  : api = ScriptApi(commandManager: commandManager),
        _additional = Map<String, Object?>.from(additional);

  final ScriptDescriptor descriptor;
  final ScriptEventType eventType;
  final Workbook workbook;
  final WorkbookCommandManager commandManager;
  final ScriptContextLog log;
  final ScriptApi api;
  final WorkbookPage? page;
  final Sheet? sheet;
  final ScriptNavigatorBinding? navigatorBinding;
  final Map<String, Object?> _additional;

  FutureOr<void> logMessage(String message) => log(message);

  SheetSelectionState? get selectionState =>
      navigatorBinding?.selectionStateFor?.call(_resolvePageKey());

  Map<String, Object?> toPayload() {
    final payload = <String, Object?>{
      'event': eventType.wireName,
      'workbook': _serialiseWorkbook(),
    };
    final page = this.page;
    if (page != null) {
      payload['page'] = _serialisePage(page);
    }
    final sheet = this.sheet;
    if (sheet != null) {
      payload['sheet'] = _serialiseSheet(sheet);
    }
    payload.addAll(_additional);
    return payload;
  }

  Map<String, Object?> _serialiseWorkbook() {
    return <String, Object?>{
      'pageCount': workbook.pages.length,
      'activeIndex': commandManager.activePageIndex,
      'pages': workbook.pages
          .map(
            (page) => <String, Object?>{
              'name': page.name,
              'type': page.runtimeType.toString(),
              'key': normaliseScriptKey(page.name),
            },
          )
          .toList(growable: false),
    };
  }

  Map<String, Object?> _serialisePage(WorkbookPage page) {
    final base = <String, Object?>{
      'name': page.name,
      'key': normaliseScriptKey(page.name),
      'scope': switch (page) {
        Sheet _ => 'sheet',
        NotesPage _ => 'notes',
        MenuPage _ => 'menu',
        _ => 'page',
      },
    };
    if (page is Sheet) {
      base['metadata'] = _serialiseSheet(page);
    }
    if (page is NotesPage) {
      base['contentLength'] = page.content.length;
    }
    return base;
  }

  Map<String, Object?> _serialiseSheet(Sheet sheet) {
    return <String, Object?>{...sheet.metadata};
  }

  String _resolvePageKey() {
    final page = this.page;
    if (page != null) {
      return normaliseScriptKey(page.name);
    }
    return descriptor.key;
  }
}
