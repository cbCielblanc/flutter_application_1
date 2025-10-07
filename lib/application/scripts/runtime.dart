import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/notes_page.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import '../../domain/workbook_page.dart';
import '../../state/sheet_selection_state.dart';
import '../commands/workbook_command_manager.dart';
import 'context.dart';
import 'models.dart';
import 'navigator_binding.dart';
import 'scope.dart';
import 'storage.dart';

typedef ScriptLogSink = FutureOr<void> Function(String message);

class ScriptRuntime {
  ScriptRuntime({
    required this.storage,
    required this.commandManager,
    ScriptLogSink? logSink,
  }) : _logSink = logSink ?? ((message) => debugPrint('[OptimaScript] $message'));

  final ScriptStorage storage;
  final WorkbookCommandManager commandManager;
  final ScriptLogSink _logSink;

  final Map<String, StoredScript> _loadedScripts = <String, StoredScript>{};

  bool _initialised = false;
  ScriptNavigatorBinding? _navigatorBinding;

  Future<void> initialize() async {
    if (_initialised) {
      return;
    }
    await storage.initialize(precompileAssets: true);
    await _ensureGlobalScript();
    _initialised = true;
  }

  Future<void> reload() async {
    _loadedScripts.clear();
    _initialised = false;
    await initialize();
  }

  Future<void> ensurePageScript(WorkbookPage page) async {
    await _ensureScript(_descriptorForPage(page));
  }

  Future<void> dispatchWorkbookOpen() async {
    await _dispatch(
      type: ScriptEventType.workbookOpen,
      pageKey: null,
    );
  }

  Future<void> dispatchWorkbookClose() async {
    await _dispatch(
      type: ScriptEventType.workbookClose,
      pageKey: null,
    );
  }

  Future<void> dispatchWorkbookBeforeSave({
    bool saveAs = false,
    bool isAutoSave = false,
  }) async {
    await _dispatch(
      type: ScriptEventType.workbookBeforeSave,
      pageKey: null,
      additional: <String, Object?>{
        'save': <String, Object?>{
          'mode': saveAs ? 'saveAs' : 'save',
          'auto': isAutoSave,
        },
      },
    );
  }

  Future<void> dispatchPageEnter(WorkbookPage page) async {
    await _dispatch(
      type: ScriptEventType.pageEnter,
      pageKey: _pageKeyFor(page),
      page: page,
    );
  }

  Future<void> dispatchPageLeave(WorkbookPage page) async {
    await _dispatch(
      type: ScriptEventType.pageLeave,
      pageKey: _pageKeyFor(page),
      page: page,
    );
  }

  Future<void> dispatchWorksheetActivate({
    required Sheet sheet,
    Sheet? previousSheet,
  }) async {
    await _dispatch(
      type: ScriptEventType.worksheetActivate,
      pageKey: _pageKeyFor(sheet),
      page: sheet,
      sheet: sheet,
      additional: <String, Object?>{
        if (previousSheet != null)
          'previousSheet': <String, Object?>{
            'name': previousSheet.name,
            'key': _pageKeyFor(previousSheet),
            'rowCount': previousSheet.rowCount,
            'columnCount': previousSheet.columnCount,
          },
      },
    );
  }

  Future<void> dispatchWorksheetDeactivate({
    required Sheet sheet,
    Sheet? nextSheet,
  }) async {
    await _dispatch(
      type: ScriptEventType.worksheetDeactivate,
      pageKey: _pageKeyFor(sheet),
      page: sheet,
      sheet: sheet,
      additional: <String, Object?>{
        if (nextSheet != null)
          'nextSheet': <String, Object?>{
            'name': nextSheet.name,
            'key': _pageKeyFor(nextSheet),
            'rowCount': nextSheet.rowCount,
            'columnCount': nextSheet.columnCount,
          },
      },
    );
  }

  Future<void> dispatchCellChanged({
    required Sheet sheet,
    required CellValueChange change,
  }) async {
    await _dispatch(
      type: ScriptEventType.cellChanged,
      pageKey: _pageKeyFor(sheet),
      page: sheet,
      sheet: sheet,
      additional: <String, Object?>{
        'cell': _serialiseCell(change.position),
        'change': <String, Object?>{
          'previousRaw': change.previousRaw,
          'previousDisplay': change.previousDisplay,
          'newRaw': change.newRaw,
          'newDisplay': change.newDisplay,
        },
      },
    );
  }

  Future<void> dispatchSelectionChanged({
    required Sheet sheet,
    required SelectionChange change,
  }) async {
    await _dispatch(
      type: ScriptEventType.selectionChanged,
      pageKey: _pageKeyFor(sheet),
      page: sheet,
      sheet: sheet,
      additional: <String, Object?>{
        'selection': <String, Object?>{
          'previous': change.previous?.label,
          'current': change.current?.label,
          'previousRow': change.previous?.row,
          'previousColumn': change.previous?.column,
          'currentRow': change.current?.row,
          'currentColumn': change.current?.column,
        },
        'interaction': <String, Object?>{'type': 'selection'},
      },
    );
  }

  Future<void> dispatchNotesChanged({
    required NotesPage page,
    required String content,
  }) async {
    await _dispatch(
      type: ScriptEventType.notesChanged,
      pageKey: _pageKeyFor(page),
      page: page,
      additional: <String, Object?>{
        'notes': <String, Object?>{'content': content},
      },
    );
  }

  Future<void> dispatchWorksheetBeforeSingleClick({
    required Sheet sheet,
    required CellPosition position,
  }) async {
    await _dispatch(
      type: ScriptEventType.worksheetBeforeSingleClick,
      pageKey: _pageKeyFor(sheet),
      page: sheet,
      sheet: sheet,
      additional: <String, Object?>{
        'cell': _serialiseCell(position),
        'interaction': <String, Object?>{'type': 'singleTap'},
      },
    );
  }

  Future<void> dispatchWorksheetBeforeDoubleClick({
    required Sheet sheet,
    required CellPosition position,
  }) async {
    await _dispatch(
      type: ScriptEventType.worksheetBeforeDoubleClick,
      pageKey: _pageKeyFor(sheet),
      page: sheet,
      sheet: sheet,
      additional: <String, Object?>{
        'cell': _serialiseCell(position),
        'interaction': <String, Object?>{'type': 'doubleTap'},
      },
    );
  }

  Future<void> _dispatch({
    required ScriptEventType type,
    String? pageKey,
    WorkbookPage? page,
    Sheet? sheet,
    Map<String, Object?> additional = const <String, Object?>{},
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
    final workbook = commandManager.workbook;
    final enriched = <String, Object?>{...additional};
    final meta = <String, Object?>{
      'eventType': type.name,
      'dispatchedAt': DateTime.now().toUtc().toIso8601String(),
      if (pageKey != null) 'pageKey': pageKey,
    };
    if (enriched.containsKey('meta') &&
        enriched['meta'] is Map<String, Object?>) {
      final existing = enriched['meta'] as Map<String, Object?>;
      meta.addAll(existing);
    }
    enriched['meta'] = meta;
    for (final script in scripts) {
      final context = ScriptContext(
        descriptor: script.descriptor,
        eventType: type,
        workbook: workbook,
        commandManager: commandManager,
        log: _logSink,
        page: page,
        sheet: sheet,
        navigatorBinding: _navigatorBinding,
        additional: enriched,
      );
      await _invokeCallback(script, type, context);
    }
  }

  Future<void> _invokeCallback(
    StoredScript script,
    ScriptEventType type,
    ScriptContext context,
  ) async {
    final callbackName = _callbackName(type);
    final export = script.export(callbackName);
    if (export == null) {
      return;
    }
    final callback = export.callback;
    try {
      await Future.sync(() => callback(context));
    } catch (error, stackTrace) {
      final message = _formatScriptError(
        script: script,
        callbackName: callbackName,
        error: error,
      );
      await Future.sync(() => _logSink(message));
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'optima_script',
          context: ErrorDescription(
            'while executing $callbackName for ${script.descriptor.fileName}',
          ),
        ),
      );
    }
  }

  String _formatScriptError({
    required StoredScript script,
    required String callbackName,
    required Object error,
  }) {
    final descriptor = script.descriptor;
    return [
      'Erreur script détectée',
      '  Script   : ${descriptor.fileName}',
      '  Callback : $callbackName',
      '  Exception: $error',
    ].join('\n');
  }

  String _callbackName(ScriptEventType type) {
    switch (type) {
      case ScriptEventType.workbookOpen:
        return 'onWorkbookOpen';
      case ScriptEventType.workbookClose:
        return 'onWorkbookClose';
      case ScriptEventType.workbookBeforeSave:
        return 'onWorkbookBeforeSave';
      case ScriptEventType.pageEnter:
        return 'onPageEnter';
      case ScriptEventType.pageLeave:
        return 'onPageLeave';
      case ScriptEventType.worksheetActivate:
        return 'onWorksheetActivate';
      case ScriptEventType.worksheetDeactivate:
        return 'onWorksheetDeactivate';
      case ScriptEventType.cellChanged:
        return 'onCellChanged';
      case ScriptEventType.selectionChanged:
        return 'onSelectionChanged';
      case ScriptEventType.notesChanged:
        return 'onNotesChanged';
      case ScriptEventType.worksheetBeforeSingleClick:
        return 'onWorksheetBeforeSingleClick';
      case ScriptEventType.worksheetBeforeDoubleClick:
        return 'onWorksheetBeforeDoubleClick';
    }
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
    final loaded = await storage.loadScript(descriptor);
    if (loaded != null) {
      _loadedScripts[cacheKey] = loaded;
    }
    return loaded;
  }

  void attachNavigatorBinding(ScriptNavigatorBinding binding) {
    _navigatorBinding = binding;
  }

  void detachNavigatorBinding() {
    _navigatorBinding = null;
  }

  ScriptNavigatorBinding? get navigatorBinding => _navigatorBinding;

  String _cacheKey(ScriptDescriptor descriptor) =>
      '${descriptor.scope.name}:${descriptor.key}';

  String _pageKeyFor(WorkbookPage page) => normaliseScriptKey(page.name);

  ScriptDescriptor _descriptorForPage(WorkbookPage page) {
    return ScriptDescriptor(scope: ScriptScope.page, key: _pageKeyFor(page));
  }

  Map<String, Object?> _serialiseCell(CellPosition position) {
    return <String, Object?>{
      'label': position.label,
      'row': position.row,
      'column': position.column,
    };
  }
}
