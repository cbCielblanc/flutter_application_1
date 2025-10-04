import 'package:meta/meta.dart';

import 'python/python_script_engine.dart';
import 'scope.dart';

export 'scope.dart';

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
  final PythonScriptModule module;
  final Map<String, PythonScriptExport> exports;

  Iterable<String> get exportNames => exports.keys;

  PythonScriptExport? operator [](String name) => exports[name];

  ScriptDocument copyWith({
    PythonScriptModule? module,
    Map<String, PythonScriptExport>? exports,
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

@immutable
class ScriptDescriptor {
  const ScriptDescriptor({required this.scope, required this.key});

  final ScriptScope scope;
  final String key;

  String get fileName {
    switch (scope) {
      case ScriptScope.global:
        return 'global/$key.py';
      case ScriptScope.page:
        return 'pages/$key.py';
      case ScriptScope.shared:
        return 'shared/$key.py';
    }
  }
}

String normaliseScriptKey(String input) {
  final buffer = StringBuffer();
  final lowered = input.trim().toLowerCase();
  var previousWasSeparator = true;
  for (final rune in lowered.runes) {
    final char = String.fromCharCode(rune);
    final isAllowed = RegExp(r'[a-z0-9]').hasMatch(char);
    if (isAllowed) {
      buffer.write(char);
      previousWasSeparator = false;
    } else if (!previousWasSeparator) {
      buffer.write('_');
      previousWasSeparator = true;
    }
  }
  var result = buffer.toString();
  result = result.replaceAll(RegExp(r'_+'), '_');
  result = result.replaceAll(RegExp(r'^_|_$'), '');
  if (result.isEmpty) {
    return 'script';
  }
  return result;
}
