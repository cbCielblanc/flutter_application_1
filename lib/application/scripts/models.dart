import 'package:meta/meta.dart';

import 'dart/dart_script_engine.dart';
import 'descriptor.dart';
import 'scope.dart';

export 'scope.dart';
export 'descriptor.dart';

@immutable
class ScriptDocument {
  const ScriptDocument({
    required this.id,
    required this.name,
    required this.scope,
    required this.module,
    required this.exports,
  });

  final String id;
  final String name;
  final ScriptScope scope;
  final DartScriptModule module;
  final Map<String, DartScriptExport> exports;

  Iterable<String> get exportNames => exports.keys;

  DartScriptExport? operator [](String name) => exports[name];

  ScriptDocument copyWith({
    DartScriptModule? module,
    Map<String, DartScriptExport>? exports,
  }) {
    return ScriptDocument(
      id: id,
      name: name,
      scope: scope,
      module: module ?? this.module,
      exports: exports ?? this.exports,
    );
  }
}

enum ScriptEventType {
  workbookOpen,
  workbookClose,
  pageEnter,
  pageLeave,
  cellChanged,
  selectionChanged,
  notesChanged,
}

extension ScriptEventTypeLabel on ScriptEventType {
  String get wireName {
    switch (this) {
      case ScriptEventType.workbookOpen:
        return 'workbook.open';
      case ScriptEventType.workbookClose:
        return 'workbook.close';
      case ScriptEventType.pageEnter:
        return 'page.enter';
      case ScriptEventType.pageLeave:
        return 'page.leave';
      case ScriptEventType.cellChanged:
        return 'cell.changed';
      case ScriptEventType.selectionChanged:
        return 'selection.changed';
      case ScriptEventType.notesChanged:
        return 'notes.changed';
    }
  }

  static ScriptEventType parse(String value) {
    switch (value) {
      case 'workbook.open':
        return ScriptEventType.workbookOpen;
      case 'workbook.close':
        return ScriptEventType.workbookClose;
      case 'page.enter':
        return ScriptEventType.pageEnter;
      case 'page.leave':
        return ScriptEventType.pageLeave;
      case 'cell.changed':
        return ScriptEventType.cellChanged;
      case 'selection.changed':
        return ScriptEventType.selectionChanged;
      case 'notes.changed':
        return ScriptEventType.notesChanged;
      default:
        throw ArgumentError('Evenement inconnu: $value');
    }
  }
}
