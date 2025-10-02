import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/menu_page.dart';
import '../../domain/notes_page.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import '../../domain/workbook_page.dart';
import '../../state/sheet_selection_state.dart';
import '../commands/workbook_command_manager.dart';
import 'models.dart';
import 'storage.dart';

typedef ScriptLogSink = FutureOr<void> Function(String message);

typedef _ContextMap = Map<String, Object?>;

class ScriptRuntime {
  ScriptRuntime({
    required this.storage,
    required this.commandManager,
    ScriptLogSink? logSink,
  }) : _logSink =
           logSink ?? ((message) => debugPrint('[OptimaScript] ' + message));

  final ScriptStorage storage;
  final WorkbookCommandManager commandManager;
  final ScriptLogSink _logSink;

  final Map<String, StoredScript> _loadedScripts = <String, StoredScript>{};
  final Map<String, StoredScript> _sharedModules = <String, StoredScript>{};

  bool _initialised = false;

  Future<void> initialize() async {
    if (_initialised) {
      return;
    }
    await _ensureGlobalScript();
    _initialised = true;
  }

  Future<void> reload() async {
    _loadedScripts.clear();
    _sharedModules.clear();
    _initialised = false;
    await initialize();
  }

  Future<void> ensurePageScript(WorkbookPage page) async {
    await _ensureScript(_descriptorForPage(page));
  }

  Future<void> dispatchWorkbookOpen() async {
    final workbook = commandManager.workbook;
    await _dispatch(
      type: ScriptEventType.workbookOpen,
      pageKey: null,
      context: _baseContext(workbook: workbook),
    );
  }

  Future<void> dispatchWorkbookClose() async {
    final workbook = commandManager.workbook;
    await _dispatch(
      type: ScriptEventType.workbookClose,
      pageKey: null,
      context: _baseContext(workbook: workbook),
    );
  }

  Future<void> dispatchPageEnter(WorkbookPage page) async {
    final workbook = commandManager.workbook;
    await _dispatch(
      type: ScriptEventType.pageEnter,
      pageKey: _pageKeyFor(page),
      context: _baseContext(workbook: workbook)
        ..addAll(_pageContext(page: page, workbook: workbook)),
    );
  }

  Future<void> dispatchPageLeave(WorkbookPage page) async {
    final workbook = commandManager.workbook;
    await _dispatch(
      type: ScriptEventType.pageLeave,
      pageKey: _pageKeyFor(page),
      context: _baseContext(workbook: workbook)
        ..addAll(_pageContext(page: page, workbook: workbook)),
    );
  }

  Future<void> dispatchCellChanged({
    required Sheet sheet,
    required CellValueChange change,
  }) async {
    final workbook = commandManager.workbook;
    final context = _baseContext(workbook: workbook)
      ..addAll(_pageContext(page: sheet, workbook: workbook))
      ..addAll({
        'cell': {
          'label': change.position.label,
          'row': change.position.row,
          'column': change.position.column,
        },
        'change': {
          'previousRaw': change.previousRaw,
          'previousDisplay': change.previousDisplay,
          'newRaw': change.newRaw,
          'newDisplay': change.newDisplay,
        },
      });
    await _dispatch(
      type: ScriptEventType.cellChanged,
      pageKey: _pageKeyFor(sheet),
      context: context,
    );
  }

  Future<void> dispatchSelectionChanged({
    required Sheet sheet,
    required SelectionChange change,
  }) async {
    final workbook = commandManager.workbook;
    final context = _baseContext(workbook: workbook)
      ..addAll(_pageContext(page: sheet, workbook: workbook))
      ..addAll({
        'selection': {
          'previous': change.previous?.label,
          'current': change.current?.label,
          'previousRow': change.previous?.row,
          'previousColumn': change.previous?.column,
          'currentRow': change.current?.row,
          'currentColumn': change.current?.column,
        },
      });
    await _dispatch(
      type: ScriptEventType.selectionChanged,
      pageKey: _pageKeyFor(sheet),
      context: context,
    );
  }

  Future<void> dispatchNotesChanged({
    required NotesPage page,
    required String content,
  }) async {
    final workbook = commandManager.workbook;
    final context = _baseContext(workbook: workbook)
      ..addAll(_pageContext(page: page, workbook: workbook))
      ..addAll({
        'notes': {'content': content},
      });
    await _dispatch(
      type: ScriptEventType.notesChanged,
      pageKey: _pageKeyFor(page),
      context: context,
    );
  }

  Future<void> _dispatch({
    required ScriptEventType type,
    required _ContextMap context,
    String? pageKey,
  }) async {
    await initialize();
    final scripts = <StoredScript>[];
    final globalScript = await _ensureGlobalScript();
    if (globalScript != null) {
      scripts.add(globalScript);
    }
    if (pageKey != null) {
      final pageScript = await _ensureScript(
        ScriptDescriptor(scope: ScriptScope.page, key: pageKey),
      );
      if (pageScript != null) {
        scripts.add(pageScript);
      }
    }
    if (scripts.isEmpty) {
      return;
    }

    for (final script in scripts) {
      await _runHandlers(script, type, context);
    }
  }

  Future<void> _runHandlers(
    StoredScript script,
    ScriptEventType type,
    _ContextMap context,
  ) async {
    final handlers = script.document.handlers
        .where((handler) => handler.eventType == type)
        .toList(growable: false);
    if (handlers.isEmpty) {
      return;
    }
    final scope = _ExecutionScope(
      runtime: this,
      script: script,
      context: context,
      commandManager: commandManager,
    );
    for (final handler in handlers) {
      if (!_filtersMatch(handler.filters, context)) {
        continue;
      }
      for (final action in handler.actions) {
        await _executeAction(action, context, scope);
      }
    }
  }

  void attachNavigatorBinding(ScriptNavigatorBinding binding) {
    _ScriptNavigatorBinding.install(binding);
  }

  void detachNavigatorBinding() {
    _ScriptNavigatorBinding.dispose();
  }

  bool _filtersMatch(Map<String, Object?> filters, _ContextMap context) {
    if (filters.isEmpty) {
      return true;
    }
    for (final entry in filters.entries) {
      final actual = _lookupContextValue(context, entry.key);
      if (actual == null && entry.value != null) {
        return false;
      }
      if (entry.value == null && actual != null) {
        return false;
      }
      if (entry.value != null && actual != null) {
        if (entry.value is String && actual is String) {
          if (entry.value != actual) {
            return false;
          }
        } else if (entry.value is num && actual is num) {
          if (entry.value != actual) {
            return false;
          }
        } else {
          if (entry.value.toString() != actual.toString()) {
            return false;
          }
        }
      }
    }
    return true;
  }

  Future<StoredScript?> _ensureGlobalScript() async {
    return _ensureScript(
      const ScriptDescriptor(scope: ScriptScope.global, key: 'default'),
    );
  }

  Future<StoredScript?> _ensureScript(ScriptDescriptor descriptor) async {
    final cacheKey = _cacheKey(descriptor);
    final cached = _loadedScripts[cacheKey];
    if (cached != null) {
      return cached;
    }
    final script = await storage.loadScript(descriptor);
    if (script == null) {
      return null;
    }
    _loadedScripts[cacheKey] = script;
    await _loadImports(script);
    return script;
  }

  Future<void> _loadImports(StoredScript script) async {
    for (final entry in script.document.imports) {
      final descriptor = _parseImport(
        entry,
        fallbackScope: script.document.scope,
      );
      if (descriptor == null) {
        continue;
      }
      final cacheKey = _cacheKey(descriptor);
      if (_loadedScripts.containsKey(cacheKey) ||
          _sharedModules.containsKey(cacheKey)) {
        continue;
      }
      final imported = await storage.loadScript(descriptor);
      if (imported == null) {
        continue;
      }
      if (descriptor.scope == ScriptScope.shared) {
        _sharedModules[cacheKey] = imported;
      } else {
        _loadedScripts[cacheKey] = imported;
      }
      await _loadImports(imported);
    }
  }

  ScriptDescriptor? _parseImport(
    String value, {
    required ScriptScope fallbackScope,
  }) {
    if (value.isEmpty) {
      return null;
    }
    if (value.contains('/')) {
      final parts = value.split('/');
      if (parts.length != 2) {
        return null;
      }
      final scopeLabel = parts.first;
      final key = parts.last;
      switch (scopeLabel) {
        case 'shared':
          return ScriptDescriptor(scope: ScriptScope.shared, key: key);
        case 'global':
          return ScriptDescriptor(scope: ScriptScope.global, key: key);
        case 'pages':
        case 'page':
          return ScriptDescriptor(scope: ScriptScope.page, key: key);
        default:
          return null;
      }
    }
    return ScriptDescriptor(scope: fallbackScope, key: value);
  }

  _ContextMap _baseContext({required Workbook workbook}) {
    return <String, Object?>{
      'workbook': {
        'pageCount': workbook.pages.length,
        'sheetCount': workbook.sheets.length,
        'pages': workbook.pages
            .map((page) => {'name': page.name, 'type': page.type})
            .toList(growable: false),
      },
    };
  }

  _ContextMap _pageContext({
    required WorkbookPage page,
    required Workbook workbook,
  }) {
    final context = <String, Object?>{
      'page': {'name': page.name, 'type': page.type},
    };
    if (page is Sheet) {
      context['sheet'] = {
        'name': page.name,
        'rowCount': page.rowCount,
        'columnCount': page.columnCount,
      };
      context['sheetKey'] = _pageKeyFor(page);
    } else if (page is NotesPage) {
      context['notes'] = {'content': page.content};
    } else if (page is MenuPage) {
      context['menu'] = {'name': page.name};
    }
    return context;
  }

  Future<void> _executeAction(
    ScriptAction action,
    _ContextMap context,
    _ExecutionScope scope,
  ) async {
    switch (action.type) {
      case 'log':
        final message =
            action.parameters['message'] ?? action.parameters['value'] ?? '';
        await _logSink(_renderTemplate(message.toString(), context));
        return;
      case 'set_cell':
        await _execSetCell(action, context, scope);
        return;
      case 'clear_cell':
        await _execClearCell(action, context, scope);
        return;
      case 'run_snippet':
        await _execRunSnippet(action, context, scope);
        return;
      default:
        await _logSink('Action inconnue: ');
    }
  }

  Future<void> _execSetCell(
    ScriptAction action,
    _ContextMap context,
    _ExecutionScope scope,
  ) async {
    final cellRef = action.parameters['cell']?.toString();
    if (cellRef == null) {
      await _logSink('set_cell: parametre "cell" manquant');
      return;
    }
    final targetSheetName = action.parameters['sheet']?.toString();
    final sheet = _resolveSheet(scope, context, targetSheetName);
    if (sheet == null) {
      await _logSink('set_cell: feuille introuvable');
      return;
    }
    final position = CellPosition.tryParse(cellRef);
    if (position == null) {
      await _logSink('set_cell: reference invalide ""');
      return;
    }
    final valueParameter =
        action.parameters['value'] ?? action.parameters['raw'];
    final templated = valueParameter == null
        ? ''
        : _renderTemplate(valueParameter.toString(), context);
    final selectionState = scope.resolveSelectionState(sheet.name);
    if (selectionState == null) {
      await _logSink('set_cell: aucun etat de selection pour ');
      return;
    }
    selectionState.setCellRawValue(position, templated);
  }

  Future<void> _execClearCell(
    ScriptAction action,
    _ContextMap context,
    _ExecutionScope scope,
  ) async {
    final cellRef = action.parameters['cell']?.toString();
    if (cellRef == null) {
      await _logSink('clear_cell: parametre "cell" manquant');
      return;
    }
    final targetSheetName = action.parameters['sheet']?.toString();
    final sheet = _resolveSheet(scope, context, targetSheetName);
    if (sheet == null) {
      await _logSink('clear_cell: feuille introuvable');
      return;
    }
    final position = CellPosition.tryParse(cellRef);
    if (position == null) {
      await _logSink('clear_cell: reference invalide ""');
      return;
    }
    final selectionState = scope.resolveSelectionState(sheet.name);
    if (selectionState == null) {
      await _logSink('clear_cell: aucun etat de selection pour ');
      return;
    }
    selectionState.setCellRawValue(position, null);
  }

  Future<void> _execRunSnippet(
    ScriptAction action,
    _ContextMap context,
    _ExecutionScope scope,
  ) async {
    final name =
        action.parameters['name']?.toString() ??
        action.parameters['value']?.toString();
    if (name == null || name.isEmpty) {
      await _logSink('run_snippet: nom manquant');
      return;
    }
    final moduleKey = action.parameters['module']?.toString();
    final snippet = _findSnippet(moduleKey, scope.script, name);
    if (snippet == null) {
      await _logSink('run_snippet: snippet "" introuvable');
      return;
    }
    final args = action.parameters['args'];
    final extendedContext = Map<String, Object?>.from(context);
    if (args is Map) {
      extendedContext['args'] = args.map(
        (key, value) => MapEntry<String, Object?>(key.toString(), value),
      );
    }
    for (final nested in snippet.actions) {
      await _executeAction(nested, extendedContext, scope);
    }
  }

  ScriptSnippet? _findSnippet(
    String? moduleKey,
    StoredScript origin,
    String name,
  ) {
    if (moduleKey == null) {
      return origin.document.snippets[name];
    }
    final descriptor = _parseImport(
      moduleKey,
      fallbackScope: ScriptScope.shared,
    );
    if (descriptor == null) {
      return null;
    }
    final cacheKey = _cacheKey(descriptor);
    final script = descriptor.scope == ScriptScope.shared
        ? _sharedModules[cacheKey]
        : _loadedScripts[cacheKey];
    return script?.document.snippets[name];
  }

  Sheet? _resolveSheet(
    _ExecutionScope scope,
    _ContextMap context,
    String? explicitName,
  ) {
    final workbook = commandManager.workbook;
    if (explicitName != null && explicitName.isNotEmpty) {
      return workbook.sheets.firstWhereOrNull(
        (sheet) => sheet.name == explicitName,
      );
    }
    final pageName = _lookupContextValue(context, 'page.name')?.toString();
    if (pageName == null) {
      return null;
    }
    return workbook.sheets.firstWhereOrNull((sheet) => sheet.name == pageName);
  }

  String _renderTemplate(String input, _ContextMap context) {
    if (input.isEmpty || !input.contains('{{')) {
      return input;
    }
    return input.replaceAllMapped(RegExp(r'\{\{([^}]+)\}\}'), (match) {
      final key = match.group(1)?.trim();
      if (key == null || key.isEmpty) {
        return '';
      }
      final value = _lookupContextValue(context, key);
      return value?.toString() ?? '';
    });
  }

  Object? _lookupContextValue(_ContextMap context, String path) {
    final segments = path.split('.');
    Object? current = context;
    for (final segment in segments) {
      if (current is Map<String, Object?>) {
        current = current[segment];
        continue;
      }
      return null;
    }
    return current;
  }

  String _pageKeyFor(WorkbookPage page) => normaliseScriptKey(page.name);

  ScriptDescriptor _descriptorForPage(WorkbookPage page) {
    return ScriptDescriptor(scope: ScriptScope.page, key: _pageKeyFor(page));
  }

  String _cacheKey(ScriptDescriptor descriptor) => ':';
}

class _ExecutionScope {
  _ExecutionScope({
    required this.runtime,
    required this.script,
    required this.context,
    required this.commandManager,
  });

  final ScriptRuntime runtime;
  final StoredScript script;
  final _ContextMap context;
  final WorkbookCommandManager commandManager;

  SheetSelectionState? resolveSelectionState(String sheetName) {
    final navigatorState = _ScriptNavigatorBinding.instance;
    return navigatorState?.selectionStateFor(sheetName);
  }
}

typedef SelectionStateResolver =
    SheetSelectionState? Function(String sheetName);

typedef NotesContentResolver = String? Function(String pageName);

typedef NotesUpdater = void Function(String pageName, String content);

class ScriptNavigatorBinding {
  ScriptNavigatorBinding({required this.selectionStateFor});

  final SelectionStateResolver selectionStateFor;
}

class _ScriptNavigatorBinding {
  const _ScriptNavigatorBinding({required this.selectionStateFor});

  final SelectionStateResolver selectionStateFor;

  static _ScriptNavigatorBinding? _instance;

  static _ScriptNavigatorBinding? get instance => _instance;

  static void install(ScriptNavigatorBinding binding) {
    _instance = _ScriptNavigatorBinding(
      selectionStateFor: binding.selectionStateFor,
    );
  }

  static void dispose() {
    _instance = null;
  }
}

extension FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
