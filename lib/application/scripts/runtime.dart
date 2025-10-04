import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:python_ffi_dart/python_ffi_dart.dart';

import '../../domain/menu_page.dart';
import '../../domain/notes_page.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import '../../domain/workbook_page.dart';
import '../../state/sheet_selection_state.dart';
import '../commands/workbook_command_manager.dart';
import 'models.dart';
import 'scope.dart';
import 'storage.dart';

typedef ScriptLogSink = FutureOr<void> Function(String message);
typedef _ContextMap = Map<String, Object?>;

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
    final context = _baseContext(workbook: workbook)
      ..addAll(_pageContext(page: page, workbook: workbook));
    await _dispatch(
      type: ScriptEventType.pageEnter,
      pageKey: _pageKeyFor(page),
      context: context,
    );
  }

  Future<void> dispatchPageLeave(WorkbookPage page) async {
    final workbook = commandManager.workbook;
    final context = _baseContext(workbook: workbook)
      ..addAll(_pageContext(page: page, workbook: workbook));
    await _dispatch(
      type: ScriptEventType.pageLeave,
      pageKey: _pageKeyFor(page),
      context: context,
    );
  }

  Future<void> dispatchCellChanged({
    required Sheet sheet,
    required CellValueChange change,
  }) async {
    final workbook = commandManager.workbook;
    final context = _baseContext(workbook: workbook)
      ..addAll(_pageContext(page: sheet, workbook: workbook))
      ..addAll(<String, Object?>{
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
      ..addAll(<String, Object?>{
        'selection': <String, Object?>{
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
      ..addAll(<String, Object?>{
        'notes': <String, Object?>{'content': content},
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
      await _invokeCallback(script, type, context);
    }
  }

  Future<void> _invokeCallback(
    StoredScript script,
    ScriptEventType type,
    _ContextMap context,
  ) async {
    final callbackName = _callbackName(type);
    final export = script.document[callbackName];
    if (export == null) {
      return;
    }
    try {
      await export.invoke<Object?>(<Object?>[context]);
    } on PythonFfiException catch (error, stackTrace) {
      await _logSink(
        'Erreur lors de l\'appel $callbackName sur ${script.descriptor.key}: $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    } catch (error, stackTrace) {
      await _logSink(
        'Exception inattendue dans $callbackName (${script.descriptor.key}): $error',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _callbackName(ScriptEventType type) {
    switch (type) {
      case ScriptEventType.workbookOpen:
        return 'on_workbook_open';
      case ScriptEventType.workbookClose:
        return 'on_workbook_close';
      case ScriptEventType.pageEnter:
        return 'on_page_enter';
      case ScriptEventType.pageLeave:
        return 'on_page_leave';
      case ScriptEventType.cellChanged:
        return 'on_cell_changed';
      case ScriptEventType.selectionChanged:
        return 'on_selection_changed';
      case ScriptEventType.notesChanged:
        return 'on_notes_changed';
    }
  }

  _ContextMap _baseContext({required Workbook workbook}) {
    final pages = workbook.pages
        .map((page) => <String, Object?>{
              'name': page.name,
              'type': page.runtimeType.toString(),
              'key': normaliseScriptKey(page.name),
            })
        .toList(growable: false);
    return <String, Object?>{
      'workbook': <String, Object?>{
        'pageCount': workbook.pages.length,
        'pages': pages,
        'activeIndex': commandManager.activePageIndex,
      },
    };
  }

  _ContextMap _pageContext({
    required WorkbookPage page,
    required Workbook workbook,
  }) {
    final base = <String, Object?>{
      'page': <String, Object?>{
        'name': page.name,
        'scope': page is Sheet
            ? 'sheet'
            : page is NotesPage
                ? 'notes'
                : page is MenuPage
                    ? 'menu'
                    : 'page',
        'key': normaliseScriptKey(page.name),
      },
    };
    if (page is Sheet) {
      base['page'] = <String, Object?>{
        ...base['page'] as Map<String, Object?>,
        ..._sheetContext(page),
      };
    }
    if (page is NotesPage) {
      base['page'] = <String, Object?>{
        ...base['page'] as Map<String, Object?>,
        'contentLength': page.content.length,
      };
    }
    return base;
  }

  Map<String, Object?> _sheetContext(Sheet sheet) {
    return <String, Object?>{
      ...sheet.metadata,
    };
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

class ScriptNavigatorBinding {
  const ScriptNavigatorBinding({
    this.selectionStateFor,
  });

  final SheetSelectionState? Function(String pageKey)? selectionStateFor;
}
