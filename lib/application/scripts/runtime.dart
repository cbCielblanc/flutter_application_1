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
        'cell': <String, Object?>{
          'label': change.position.label,
          'row': change.position.row,
          'column': change.position.column,
        },
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
        additional: additional,
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
      Error.throwWithStackTrace(error, stackTrace);
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
      case ScriptEventType.pageEnter:
        return 'onPageEnter';
      case ScriptEventType.pageLeave:
        return 'onPageLeave';
      case ScriptEventType.cellChanged:
        return 'onCellChanged';
      case ScriptEventType.selectionChanged:
        return 'onSelectionChanged';
      case ScriptEventType.notesChanged:
        return 'onNotesChanged';
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
}
