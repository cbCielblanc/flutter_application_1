import 'package:meta/meta.dart';

@immutable
class ScriptDocument {
  const ScriptDocument({
    required this.id,
    required this.name,
    required this.scope,
    required this.handlers,
    this.imports = const <String>[],
    this.snippets = const <String, ScriptSnippet>{},
  });

  final String id;
  final String name;
  final ScriptScope scope;
  final List<String> imports;
  final Map<String, ScriptSnippet> snippets;
  final List<ScriptHandler> handlers;

  ScriptDocument copyWith({
    List<ScriptHandler>? handlers,
    Map<String, ScriptSnippet>? snippets,
  }) {
    return ScriptDocument(
      id: id,
      name: name,
      scope: scope,
      imports: imports,
      snippets: snippets ?? this.snippets,
      handlers: handlers ?? this.handlers,
    );
  }
}

enum ScriptScope { global, page, shared }

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
class ScriptHandler {
  const ScriptHandler({
    required this.eventType,
    required this.actions,
    this.filters = const <String, Object?>{},
    this.description,
  });

  final ScriptEventType eventType;
  final Map<String, Object?> filters;
  final List<ScriptAction> actions;
  final String? description;
}

@immutable
class ScriptAction {
  const ScriptAction({
    required this.type,
    this.parameters = const <String, Object?>{},
    this.description,
  });

  final String type;
  final Map<String, Object?> parameters;
  final String? description;
}

@immutable
class ScriptSnippet {
  const ScriptSnippet({
    required this.name,
    required this.actions,
    this.description,
  });

  final String name;
  final List<ScriptAction> actions;
  final String? description;
}

@immutable
class ScriptDescriptor {
  const ScriptDescriptor({required this.scope, required this.key});

  final ScriptScope scope;
  final String key;

  String get fileName {
    switch (scope) {
      case ScriptScope.global:
        return 'global/$key.yaml';
      case ScriptScope.page:
        return 'pages/$key.yaml';
      case ScriptScope.shared:
        return 'shared/$key.yaml';
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

class ScriptParseException implements Exception {
  ScriptParseException(this.message);

  final String message;

  @override
  String toString() => 'ScriptParseException: $message';
}
