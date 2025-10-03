import 'dart:async';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/languages/yaml.dart';

import '../application/scripts/models.dart';
import '../application/scripts/runtime.dart';
import '../application/scripts/storage.dart';

import '../application/commands/add_notes_page_command.dart';
import '../application/commands/add_sheet_command.dart';
import '../application/commands/command_utils.dart';
import '../application/commands/remove_notes_page_command.dart';
import '../application/commands/remove_sheet_command.dart';
import '../application/commands/workbook_command_manager.dart';
import '../domain/cell.dart';
import '../domain/menu_page.dart';
import '../domain/notes_page.dart';
import '../domain/sheet.dart';
import '../domain/workbook.dart';
import '../domain/workbook_page.dart';
import '../state/sheet_selection_state.dart';
import 'themes/highlight_themes.dart';
import 'widgets/command_ribbon.dart';
import 'widgets/formula_bar.dart';
import 'widgets/menu_page_view.dart';
import 'widgets/notes_page_view.dart';
import 'widgets/sheet_grid.dart';
import 'widgets/workbook_page_tab_bar.dart';
import 'workbook_page_display.dart';

class CustomAction {
  CustomAction({
    required this.id,
    required this.label,
    required this.template,
  });

  final String id;
  final String label;
  final String template;
}

class WorkbookNavigator extends StatefulWidget {
  const WorkbookNavigator({
    super.key,
    required this.commandManager,
    required this.scriptRuntime,
    required this.isAdmin,
  });

  final WorkbookCommandManager commandManager;
  final ScriptRuntime scriptRuntime;
  final bool isAdmin;

  @override
  State<WorkbookNavigator> createState() => _WorkbookNavigatorState();
}

class _WorkbookNavigatorState extends State<WorkbookNavigator>
    with TickerProviderStateMixin {
  late PageController _pageController;
  final Map<String, SheetSelectionState> _selectionStates =
      <String, SheetSelectionState>{};
  final Map<String, TextEditingController> _notesControllers =
      <String, TextEditingController>{};
  final Map<String, VoidCallback> _notesListeners =
      <String, VoidCallback>{};
  final List<CustomAction> _customActions = <CustomAction>[];
  late final TextEditingController _customActionLabelController;
  late final TextEditingController _customActionTemplateController;
  late final CodeController _scriptEditorController;
  final TextEditingController _sharedScriptKeyController =
      TextEditingController(text: 'shared_module');
  ScriptScope _scriptEditorScope = ScriptScope.page;
  String? _scriptEditorPageName;
  String _scriptSharedKey = 'shared_module';
  bool _scriptEditorLoading = false;
  bool _scriptEditorDirty = false;
  String? _scriptEditorStatus;
  ScriptDescriptor? _currentScriptDescriptor;
  bool _suppressScriptEditorChanges = false;
  bool _scriptEditorFullscreen = false;
  bool _scriptEditorSplitPreview = false;
  late int _currentPageIndex;
  final List<StoredScript> _scriptLibrary = <StoredScript>[];
  bool _scriptLibraryLoading = false;
  String? _scriptLibraryError;

  WorkbookCommandManager get _manager => widget.commandManager;
  ScriptRuntime get _runtime => widget.scriptRuntime;
  bool get _isAdmin => widget.isAdmin;

  @override
  void initState() {
    super.initState();
    _customActionLabelController = TextEditingController();
    _customActionTemplateController = TextEditingController();
    _scriptEditorController = CodeController(
      language: yaml,
      params: const EditorParams(tabSpaces: 2),
    );
    _scriptEditorController.addListener(_handleScriptEditorChanged);
    _sharedScriptKeyController.addListener(_handleSharedScriptKeyChanged);
    if (_isAdmin) {
      _initialiseCustomActions();
      unawaited(_refreshScriptLibrary());
    }
    final initialPageIndex = _manager.activePageIndex;
    final pages = _manager.workbook.pages;
    if (pages.isNotEmpty) {
      final safeIndex = initialPageIndex >= 0 && initialPageIndex < pages.length
          ? initialPageIndex
          : 0;
      _scriptEditorPageName = pages[safeIndex].name;
    }
    _currentPageIndex = initialPageIndex;
    _pageController = PageController(
      initialPage: initialPageIndex < 0 ? 0 : initialPageIndex,
    );
    _manager.addListener(_handleManagerChanged);
    if (_isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadScriptEditor());
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant WorkbookNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commandManager != widget.commandManager) {
      oldWidget.commandManager.removeListener(_handleManagerChanged);
      final newIndex = widget.commandManager.activePageIndex;
      _currentPageIndex = newIndex;
      _pageController.dispose();
      _pageController = PageController(
        initialPage: newIndex < 0 ? 0 : newIndex,
      );
      widget.commandManager.addListener(_handleManagerChanged);
    }
    if (!oldWidget.isAdmin && widget.isAdmin) {
      _initialiseCustomActions();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_refreshScriptLibrary());
        unawaited(_loadScriptEditor());
      });
    }
  }

  void _handleManagerChanged() {
    final workbook = _manager.workbook;
    final sheets = workbook.sheets;
    final notesPages = workbook.pages.whereType<NotesPage>().toList();

    final removedSheets = _selectionStates.keys
        .where((name) => sheets.every((sheet) => sheet.name != name))
        .toList(growable: false);
    for (final sheet in removedSheets) {
      _selectionStates.remove(sheet)?.dispose();
    }

    final removedNotes = _notesControllers.keys
        .where((name) => notesPages.every((page) => page.name != name))
        .toList(growable: false);
    for (final noteName in removedNotes) {
      final controller = _notesControllers.remove(noteName);
      final listener = _notesListeners.remove(noteName);
      if (controller != null && listener != null) {
        controller.removeListener(listener);
      }
      controller?.dispose();
    }

    final newIndex = _manager.activePageIndex;
    if (newIndex != _currentPageIndex) {
      _commitEditsForPage(workbook, _currentPageIndex);
      _currentPageIndex = newIndex;
      _jumpToPage(newIndex);
    }
    if (_scriptEditorScope == ScriptScope.page) {
      final pageNames = workbook.pages.map((page) => page.name).toList();
      final currentSelection = _scriptEditorPageName;
      if (currentSelection == null || !pageNames.contains(currentSelection)) {
        final fallback = pageNames.isNotEmpty ? pageNames.first : null;
        if (fallback != currentSelection) {
          setState(() {
            _scriptEditorPageName = fallback;
          });
          if (_isAdmin && fallback != null) {
            unawaited(_loadScriptEditor());
          }
        }
      }
    }
    if (_isAdmin) {
      unawaited(_refreshScriptLibrary(silent: true));
    }
  }

  void _jumpToPage(int index) {
    if (index < 0) {
      return;
    }
    final pageCount = _manager.workbook.pages.length;
    if (pageCount == 0) {
      return;
    }
    final targetIndex = index >= pageCount ? pageCount - 1 : index;
    if (!_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pageController.jumpToPage(targetIndex);
        }
      });
      return;
    }
    if (_pageController.page?.round() == targetIndex) {
      return;
    }
    _pageController.animateToPage(
      targetIndex,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _manager.removeListener(_handleManagerChanged);
    _scriptEditorController.removeListener(_handleScriptEditorChanged);
    _sharedScriptKeyController.removeListener(_handleSharedScriptKeyChanged);
    _pageController.dispose();
    for (final state in _selectionStates.values) {
      state.dispose();
    }
    _notesControllers.forEach((name, controller) {
      final listener = _notesListeners[name];
      if (listener != null) {
        controller.removeListener(listener);
      }
      controller.dispose();
    });
    _customActionLabelController.dispose();
    _customActionTemplateController.dispose();
    _scriptEditorController.dispose();
    _sharedScriptKeyController.dispose();
    super.dispose();
  }

  SheetSelectionState _stateForSheet(Workbook workbook, Sheet sheet) {
    final state = _selectionStates.putIfAbsent(
      sheet.name,
      () => SheetSelectionState(
        onValuesChanged: (values) => _persistSheetValues(sheet.name, values),
      ),
    );
    state.onValuesChanged =
        (values) => _persistSheetValues(sheet.name, values);
    state.syncFromSheet(sheet);
    return state;
  }

  void _commitEditsForSheet(String sheetName) {
    final state = _selectionStates[sheetName];
    state?.commitEditingValue();
  }

  void _commitEditsForPage(Workbook workbook, int pageIndex) {
    if (pageIndex < 0 || pageIndex >= workbook.pages.length) {
      return;
    }
    final page = workbook.pages[pageIndex];
    if (page is Sheet) {
      _commitEditsForSheet(page.name);
    }
  }

  TextEditingController _controllerForNotesPage(NotesPage page) {
    final existing = _notesControllers[page.name];
    if (existing != null) {
      if (existing.text != page.content) {
        final listener = _notesListeners[page.name];
        if (listener != null) {
          existing.removeListener(listener);
        }
        final previousSelection = existing.selection;
        existing.value = existing.value.copyWith(
          text: page.content,
          selection: previousSelection,
          composing: TextRange.empty,
        );
        if (listener != null) {
          existing.addListener(listener);
        }
      }
      return existing;
    }
    final controller = TextEditingController(text: page.content);
    void handleChange() => _handleNotesChanged(page.name, controller.text);
    controller.addListener(handleChange);
    _notesControllers[page.name] = controller;
    _notesListeners[page.name] = handleChange;
    return controller;
  }

  void _handleNotesChanged(String pageName, String content) {

    final workbook = _manager.workbook;

    final pageIndex = workbook.pages.indexWhere(

      (page) => page.name == pageName,

    );

    if (pageIndex == -1) {

      return;

    }

    final page = workbook.pages[pageIndex];

    if (page is! NotesPage) {

      return;

    }

    if (page.content == content) {

      return;

    }

    final updatedPage = page.copyWith(content: content);

    final updatedWorkbook = replacePage(workbook, pageIndex, updatedPage);

    _manager.applyExternalUpdate(

      updatedWorkbook,

      activePageIndex: _manager.activePageIndex,

    );

    unawaited(

      _runtime.dispatchNotesChanged(page: updatedPage, content: content),

    );

  }



  void _handleSelectPage(int pageIndex) {
    final workbook = _manager.workbook;
    if (pageIndex < 0 || pageIndex >= workbook.pages.length) {
      return;
    }
    _commitEditsForPage(workbook, _currentPageIndex);
    _manager.setActivePage(pageIndex);
  }

  void _handleAddSheet() {
    _commitActiveSelectionEdits();
    _manager.execute(AddSheetCommand());
  }

  void _handleAddNotesPage() {
    _commitActiveSelectionEdits();
    _manager.execute(AddNotesPageCommand());
  }

  void _handleRemovePage(int pageIndex) {
    _commitActiveSelectionEdits();
    final workbook = _manager.workbook;
    if (pageIndex < 0 || pageIndex >= workbook.pages.length) {
      return;
    }
    final page = workbook.pages[pageIndex];
    if (page is Sheet) {
      final sheetIndex = workbook.sheets.indexOf(page);
      if (sheetIndex != -1) {
        _selectionStates.remove(page.name)?.dispose();
        _manager.execute(RemoveSheetCommand(sheetIndex: sheetIndex));
      }
      return;
    }
    if (page is NotesPage) {
      _manager.execute(RemoveNotesPageCommand(pageIndex: pageIndex));
    }
  }

  bool _canRemovePage(Workbook workbook, int pageIndex) {
    if (pageIndex < 0 || pageIndex >= workbook.pages.length) {
      return false;
    }
    final page = workbook.pages[pageIndex];
    if (page is MenuPage) {
      return false;
    }
    if (page is Sheet) {
      return workbook.sheets.length > 1;
    }
    return true;
  }

  void _handleRemoveSheet(int sheetIndex) {
    _commitActiveSelectionEdits();
    final workbook = _manager.workbook;
    if (sheetIndex < 0 || sheetIndex >= workbook.sheets.length) {
      return;
    }
    final sheetName = workbook.sheets[sheetIndex].name;
    _selectionStates.remove(sheetName)?.dispose();
    _manager.execute(RemoveSheetCommand(sheetIndex: sheetIndex));
  }

  void _commitActiveSelectionEdits() {
    _commitEditsForPage(_manager.workbook, _manager.activePageIndex);
  }

  void _persistSheetValues(
    String sheetName,
    Map<CellPosition, String> values,
  ) {
    final workbook = _manager.workbook;
    Sheet? targetSheet;
    for (final sheet in workbook.sheets) {
      if (sheet.name == sheetName) {
        targetSheet = sheet;
        break;
      }
    }
    if (targetSheet == null) {
      return;
    }

    final pageIndex = workbook.pages.indexOf(targetSheet);
    if (pageIndex == -1) {
      return;
    }

    final rows = cloneSheetRows(targetSheet);
    var didChange = false;
    for (var r = 0; r < targetSheet.rowCount; r++) {
      final row = rows[r];
      for (var c = 0; c < targetSheet.columnCount; c++) {
        final position = CellPosition(r, c);
        final text = values[position];
        if (text == null || text.isEmpty) {
          final cell = row[c];
          if (cell.type != CellType.empty || cell.value != null) {
            row[c] = Cell(row: r, column: c, type: CellType.empty, value: null);
            didChange = true;
          }
          continue;
        }

        final nextCell = Cell.fromValue(row: r, column: c, value: text);
        final currentCell = row[c];
        if (currentCell.type != nextCell.type ||
            currentCell.value != nextCell.value) {
          row[c] = nextCell;
          didChange = true;
        }
      }
    }

    if (!didChange) {
      return;
    }

    final updatedSheet = rebuildSheetFromRows(targetSheet, rows);
    final updatedWorkbook = replaceSheetAtPageIndex(
      workbook,
      pageIndex,
      updatedSheet,
    );
    _manager.applyExternalUpdate(
      updatedWorkbook,
      activePageIndex: _manager.activePageIndex,
    );
  }

  void _handleScriptEditorChanged() {
    if (_suppressScriptEditorChanges) {
      return;
    }
    if (!_scriptEditorDirty || _scriptEditorSplitPreview) {
      setState(() {
        _scriptEditorDirty = true;
      });
    }
  }

  void _handleSharedScriptKeyChanged() {
    final value = normaliseScriptKey(_sharedScriptKeyController.text);
    if (value != _scriptSharedKey) {
      setState(() {
        _scriptSharedKey = value;
      });
    }
  }

  Future<void> _refreshScriptLibrary({bool silent = false}) async {
    if (!_isAdmin) {
      return;
    }
    if (!silent) {
      setState(() {
        _scriptLibraryLoading = true;
        _scriptLibraryError = null;
      });
    }
    try {
      final scripts = await _runtime.storage.loadAll();
      if (!mounted) {
        return;
      }
      setState(() {
        _scriptLibrary
          ..clear()
          ..addAll(scripts);
        _scriptLibraryLoading = false;
        _scriptLibraryError = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scriptLibraryLoading = false;
        _scriptLibraryError = 'Erreur de chargement: $error';
      });
    }
  }

  ScriptDescriptor? _descriptorForSelection() {
    switch (_scriptEditorScope) {
      case ScriptScope.global:
        return const ScriptDescriptor(scope: ScriptScope.global, key: 'default');
      case ScriptScope.page:
        final pageName = _scriptEditorPageName;
        if (pageName == null || pageName.isEmpty) {
          return null;
        }
        return ScriptDescriptor(
          scope: ScriptScope.page,
          key: normaliseScriptKey(pageName),
        );
      case ScriptScope.shared:
        if (_scriptSharedKey.isEmpty) {
          return null;
        }
        return ScriptDescriptor(scope: ScriptScope.shared, key: _scriptSharedKey);
    }
  }

  bool _hasScriptDescriptor(ScriptDescriptor descriptor) {
    return _scriptLibrary.any(
      (script) =>
          script.descriptor.scope == descriptor.scope &&
          script.descriptor.key == descriptor.key,
    );
  }

  Future<void> _handleSelectScriptDescriptor(
    ScriptDescriptor descriptor, {
    String? pageName,
    String? rawSharedKey,
  }) async {
    setState(() {
      _scriptEditorScope = descriptor.scope;
      switch (descriptor.scope) {
        case ScriptScope.global:
          break;
        case ScriptScope.page:
          String? resolvedName = pageName;
          if (resolvedName == null) {
            for (final page in _manager.workbook.pages) {
              if (normaliseScriptKey(page.name) == descriptor.key) {
                resolvedName = page.name;
                break;
              }
            }
          }
          if (resolvedName != null) {
            _scriptEditorPageName = resolvedName;
          }
          break;
        case ScriptScope.shared:
          final rawValue = rawSharedKey ?? descriptor.key;
          _sharedScriptKeyController.removeListener(_handleSharedScriptKeyChanged);
          _sharedScriptKeyController.text = rawValue;
          _sharedScriptKeyController.selection =
              TextSelection.collapsed(offset: rawValue.length);
          _sharedScriptKeyController.addListener(_handleSharedScriptKeyChanged);
          _scriptSharedKey = normaliseScriptKey(rawValue);
          break;
      }
    });
    await _loadScriptEditor();
  }

  Future<void> _promptNewSharedModule(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouveau module partagé'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom du module',
              hintText: 'ex: automatisations',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) {
      return;
    }
    final raw = result.trim();
    if (raw.isEmpty) {
      return;
    }
    final descriptor = ScriptDescriptor(
      scope: ScriptScope.shared,
      key: normaliseScriptKey(raw),
    );
    await _handleSelectScriptDescriptor(
      descriptor,
      rawSharedKey: raw,
    );
  }


  String _normaliseCustomActionTemplate(String template) {
    var value = template;
    if (value.startsWith('\n')) {
      value = value.substring(1);
    }
    if (!value.endsWith('\n')) {
      value = '$value\n';
    }
    return value;
  }

  void _initialiseCustomActions() {
    if (_customActions.isNotEmpty) {
      return;
    }
    _customActions.addAll(<CustomAction>[
      CustomAction(
        id: 'log',
        label: 'Ajouter un log',
        template: _normaliseCustomActionTemplate('''
  - log:
      message: "Votre message"
'''),
      ),
      CustomAction(
        id: 'set_cell',
        label: 'Ecrire une cellule',
        template: _normaliseCustomActionTemplate('''
  - set_cell:
      cell: A1
      value: "=B1"
'''),
      ),
      CustomAction(
        id: 'run_snippet',
        label: 'Executer un snippet',
        template: _normaliseCustomActionTemplate('''
  - run_snippet:
      module: shared/default
      name: votre_snippet
      args:
        target: A1
'''),
      ),
    ]);
  }

  Future<void> _handleSaveScript() async {
    final descriptor = _resolveScriptDescriptor();
    if (descriptor == null) {
      setState(() {
        _scriptEditorStatus =
            "Impossible d'enregistrer: aucun script selectionne.";
      });
      return;
    }
    setState(() {
      _scriptEditorLoading = true;
      _scriptEditorStatus = 'Enregistrement du script...';
    });
    try {
      final stored =
          await _runtime.storage.saveScript(descriptor, _scriptEditorController.text);
      await _runtime.reload();
      await _refreshScriptLibrary(silent: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentScriptDescriptor = stored.descriptor;
        _scriptEditorDirty = false;
        _scriptEditorStatus = 'Script enregistre dans ${stored.origin}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scriptEditorStatus =
            "Erreur lors de l'enregistrement du script: $error";
      });
    } finally {
      if (mounted) {
        setState(() {
          _scriptEditorLoading = false;
        });
      }
    }
  }

  Future<void> _handleReloadScripts() async {
    try {
      setState(() {
        _scriptEditorStatus = 'Rechargement des scripts...';
      });
      await _runtime.reload();
      await _refreshScriptLibrary(silent: true);
      await _loadScriptEditor();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scriptEditorStatus = 'Erreur lors du rechargement: $error';
      });
    }
  }

  ScriptDescriptor? _resolveScriptDescriptor() {
    switch (_scriptEditorScope) {
      case ScriptScope.global:
        return const ScriptDescriptor(scope: ScriptScope.global, key: 'default');
      case ScriptScope.page:
        final pageName = _scriptEditorPageName ??
            (_manager.workbook.pages.isNotEmpty
                ? _manager.workbook.pages.first.name
                : null);
        if (pageName == null) {
          return null;
        }
        return ScriptDescriptor(
          scope: ScriptScope.page,
          key: normaliseScriptKey(pageName),
        );
      case ScriptScope.shared:
        final raw = _sharedScriptKeyController.text.trim();
        if (raw.isEmpty && _scriptSharedKey.isEmpty) {
          return null;
        }
        final key = raw.isNotEmpty ? normaliseScriptKey(raw) : _scriptSharedKey;
        return ScriptDescriptor(scope: ScriptScope.shared, key: key);
    }
  }

  Future<void> _loadScriptEditor() async {
    final descriptor = _resolveScriptDescriptor();
    if (descriptor == null) {
      setState(() {
        _currentScriptDescriptor = null;
        _scriptEditorLoading = false;
        _suppressScriptEditorChanges = true;
        _scriptEditorController.clear();
        _suppressScriptEditorChanges = false;
        _scriptEditorDirty = false;
        _scriptEditorStatus =
            'Selectionnez un script a charger pour commencer.';
      });
      return;
    }
    setState(() {
      _scriptEditorLoading = true;
      _scriptEditorStatus = 'Chargement de ${descriptor.fileName}...';
    });
    try {
      final stored = await _runtime.storage.loadScript(descriptor);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentScriptDescriptor = descriptor;
        _suppressScriptEditorChanges = true;
        _scriptEditorController.text = stored?.source ??
            _defaultScriptTemplate(descriptor);
        _suppressScriptEditorChanges = false;
        _scriptEditorDirty = false;
        _scriptEditorStatus = stored == null
            ? 'Aucun script trouve. Un modele par defaut a ete genere.'
            : 'Script charge depuis ${stored.origin}.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scriptEditorStatus = 'Erreur lors du chargement: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _scriptEditorLoading = false;
        });
      }
    }
  }

  String _defaultScriptTemplate(ScriptDescriptor descriptor) {
    switch (descriptor.scope) {
      case ScriptScope.global:
        return 'name: Global Script\n'
            'scope: global\n'
            'handlers:\n'
            '  - event: workbook.open\n'
            '    actions:\n'
            '      - log:\n'
            '          message: "Classeur ouvert"\n';
      case ScriptScope.page:
        return 'name: Page Script\n'
            'scope: page\n'
            'handlers:\n'
            '  - event: page.enter\n'
            '    actions:\n'
            '      - log:\n'
            '          message: "Bienvenue sur {{page.name}}"\n';
      case ScriptScope.shared:
        return 'name: Module partage\n'
            'scope: shared\n'
            'snippets:\n'
            '  exemple:\n'
            '    description: Exemple de snippet\n'
            '    actions:\n'
            '      - log:\n'
            '          message: "Execution du snippet"\n';
    }
  }

  Widget _buildAdminWorkspace(BuildContext context) {
    final theme = Theme.of(context);
    final workbook = _manager.workbook;
    final pages = workbook.pages;
    final isDark = theme.brightness == Brightness.dark;
    final codeTheme = CodeThemeData(
      styles: isDark ? monokaiSublimeTheme : githubTheme,
    );
    final lineNumberStyle = LineNumberStyle(
      width: 48,
      textStyle: theme.textTheme.bodySmall,
    );
    final descriptor = _currentScriptDescriptor;
    final status = _scriptEditorStatus;
    final scriptFileName = descriptor?.fileName;
    final activeDescriptor = _descriptorForSelection() ?? descriptor;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: DefaultTabController(
        length: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: theme.colorScheme.surface,
              child: TabBar(
                labelColor: theme.colorScheme.primary,
                indicatorColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(icon: Icon(Icons.code), text: 'Scripts'),
                  Tab(icon: Icon(Icons.menu_book_outlined), text: 'Documentation'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildAdminEditorLayout(
                    context: context,
                    codeTheme: codeTheme,
                    lineNumberStyle: lineNumberStyle,
                    pages: pages,
                    activeDescriptor: activeDescriptor,
                    scriptFileName: scriptFileName,
                    status: status,
                  ),
                  _buildAdminDocumentationTab(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminEditorLayout({
    required BuildContext context,
    required CodeThemeData codeTheme,
    required LineNumberStyle lineNumberStyle,
    required List<WorkbookPage> pages,
    required ScriptDescriptor? activeDescriptor,
    required String? scriptFileName,
    required String? status,
  }) {
    final theme = Theme.of(context);
    final editorSurface = _buildScriptEditorSurface(
      context: context,
      codeTheme: codeTheme,
      lineNumberStyle: lineNumberStyle,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Espace de développement',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: _scriptEditorSplitPreview
                    ? 'Fermer la vue scindée'
                    : 'Afficher la vue scindée',
                color:
                    _scriptEditorSplitPreview ? theme.colorScheme.primary : null,
                onPressed: () {
                  setState(() {
                    _scriptEditorSplitPreview = !_scriptEditorSplitPreview;
                  });
                },
                icon: const Icon(Icons.vertical_split),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: _scriptEditorFullscreen
                    ? 'Quitter le plein écran'
                    : 'Afficher en plein écran',
                color:
                    _scriptEditorFullscreen ? theme.colorScheme.primary : null,
                onPressed: () {
                  setState(() {
                    _scriptEditorFullscreen = !_scriptEditorFullscreen;
                  });
                },
                icon: Icon(
                  _scriptEditorFullscreen
                      ? Icons.close_fullscreen
                      : Icons.open_in_full,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Recharger tous les scripts',
                onPressed: _scriptEditorLoading ? null : _handleReloadScripts,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: (_scriptEditorLoading || !_scriptEditorDirty)
                    ? null
                    : _handleSaveScript,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _scriptEditorDirty ? 'Enregistrer*' : 'Enregistrer',
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_scriptEditorFullscreen) ...[
                SizedBox(
                  width: 240,
                  child: _buildScriptLibraryPanel(
                    context: context,
                    pages: pages,
                    activeDescriptor: activeDescriptor,
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (scriptFileName != null)
                        Text(
                          'Fichier actuel : $scriptFileName',
                          style: theme.textTheme.bodySmall,
                        ),
                      if (scriptFileName != null) const SizedBox(height: 8),
                      if (_customActions.isNotEmpty) _buildCustomActionsBar(context),
                      if (_customActions.isNotEmpty) const SizedBox(height: 12),
                      if (_scriptEditorFullscreen)
                        Expanded(child: editorSurface)
                      else
                        Flexible(fit: FlexFit.tight, child: editorSurface),
                      const SizedBox(height: 8),
                      if (status != null)
                        Text(
                          status,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScriptEditorSurface({
    required BuildContext context,
    required CodeThemeData codeTheme,
    required LineNumberStyle lineNumberStyle,
  }) {
    final theme = Theme.of(context);
    final borderDecoration = BoxDecoration(
      border: Border.all(
        color: theme.colorScheme.outline.withOpacity(0.25),
      ),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    );

    final editor = CodeTheme(
      data: codeTheme,
      child: DecoratedBox(
        decoration: borderDecoration,
        child: Stack(
          children: [
            Positioned.fill(
              child: CodeField(
                controller: _scriptEditorController,
                expands: true,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                ),
                lineNumberStyle: lineNumberStyle,
                padding: const EdgeInsets.all(12),
                background: theme.colorScheme.surface,
              ),
            ),
            if (_scriptEditorLoading)
              const Positioned(
                top: 16,
                right: 16,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        ),
      ),
    );

    Widget buildPreview() {
      return DecoratedBox(
        decoration: borderDecoration,
        child: Material(
          type: MaterialType.transparency,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              _scriptEditorController.text.isEmpty
                  ? 'Aucun contenu pour le moment.'
                  : _scriptEditorController.text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        Widget content = editor;

        if (_scriptEditorSplitPreview) {
          content = SizedBox(
            height: constraints.maxHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: editor),
                const VerticalDivider(width: 1),
                Expanded(child: buildPreview()),
              ],
            ),
          );
        }

        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          vsync: this,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: content,
          ),
        );
      },
    );
  }


  Widget _buildScriptLibraryPanel({
    required BuildContext context,
    required List<WorkbookPage> pages,
    required ScriptDescriptor? activeDescriptor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sharedScripts = _scriptLibrary
        .where((script) => script.descriptor.scope == ScriptScope.shared)
        .toList()
      ..sort((a, b) => a.descriptor.key.compareTo(b.descriptor.key));

    final globalDescriptor =
        const ScriptDescriptor(scope: ScriptScope.global, key: 'default');
    final globalHasScript = _hasScriptDescriptor(globalDescriptor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Bibliothèque de scripts', style: theme.textTheme.titleSmall),
        ),
        Expanded(
          child: _scriptLibraryLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    _buildScriptGroupHeader(context, 'Classeur'),
                    _buildScriptLibraryTile(
                      context: context,
                      icon: Icons.language,
                      label: 'Script global',
                      subtitle: globalHasScript
                          ? 'Script existant'
                          : 'Déclenché pour tout le classeur',
                      selected: activeDescriptor?.scope == ScriptScope.global,
                      hasContent: globalHasScript,
                      onTap: () =>
                          _handleSelectScriptDescriptor(globalDescriptor),
                    ),
                    const SizedBox(height: 12),
                    _buildScriptGroupHeader(context, 'Pages'),
                    if (pages.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Text(
                          'Aucune page disponible.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ...pages.map((page) {
                      final descriptor = ScriptDescriptor(
                        scope: ScriptScope.page,
                        key: normaliseScriptKey(page.name),
                      );
                      final hasScript = _hasScriptDescriptor(descriptor);
                      final selected =
                          activeDescriptor?.scope == ScriptScope.page &&
                              activeDescriptor?.key == descriptor.key;
                      return _buildScriptLibraryTile(
                        context: context,
                        icon: Icons.grid_on_outlined,
                        label: page.name,
                        subtitle: hasScript
                            ? 'Script existant'
                            : 'Créer un script pour cette page',
                        selected: selected,
                        hasContent: hasScript,
                        onTap: () => _handleSelectScriptDescriptor(
                          descriptor,
                          pageName: page.name,
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    _buildScriptGroupHeader(context, 'Modules partagés'),
                    if (sharedScripts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Text(
                          'Créez un module pour factoriser vos snippets.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ...sharedScripts.map((script) {
                      final descriptor = script.descriptor;
                      final selected =
                          activeDescriptor?.scope == ScriptScope.shared &&
                              activeDescriptor?.key == descriptor.key;
                      return _buildScriptLibraryTile(
                        context: context,
                        icon: Icons.extension,
                        label: descriptor.key,
                        subtitle: 'Module partagé',
                        selected: selected,
                        hasContent: true,
                        onTap: () => _handleSelectScriptDescriptor(
                          descriptor,
                          rawSharedKey: descriptor.key,
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: OutlinedButton.icon(
                        onPressed: () => _promptNewSharedModule(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Nouveau module partagé'),
                      ),
                    ),
                  ],
                ),
        ),
        if (_scriptLibraryError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              _scriptLibraryError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAdminDocumentationTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final codeBackground = isDark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.4)
        : theme.colorScheme.surfaceVariant;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Guide de référence rapide',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'Les scripts Optima sont écrits en YAML. Chaque script définit un nom, une portée (global, page ou module partagé) et une liste de gestionnaires d’évènements.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text('Événements disponibles', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildDocBullet(
          context,
          'workbook.open',
          'Déclenché lors de l’ouverture du classeur.',
        ),
        _buildDocBullet(
          context,
          'workbook.close',
          'Déclenché à la fermeture du classeur.',
        ),
        _buildDocBullet(
          context,
          'page.enter',
          'Appelé quand un utilisateur arrive sur une page.',
        ),
        _buildDocBullet(
          context,
          'page.leave',
          'Appelé avant de quitter la page active.',
        ),
        _buildDocBullet(
          context,
          'cell.changed',
          'Notifié lorsqu’une cellule change de valeur.',
        ),
        _buildDocBullet(
          context,
          'selection.changed',
          'Notifié lorsqu’une sélection de cellules est modifiée.',
        ),
        _buildDocBullet(
          context,
          'notes.changed',
          'Déclenché lorsque le contenu d’une page de notes est édité.',
        ),
        const SizedBox(height: 16),
        Text('Actions supportées', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildDocBullet(
          context,
          'log',
          'Affiche un message dans la console des scripts. Utilisez le paramètre "message" pour personnaliser le texte.',
        ),
        _buildDocBullet(
          context,
          'set_cell',
          'Écrit une valeur dans une cellule (paramètres : cell, sheet?, value/raw). Les expressions sont évaluées après substitution des variables de contexte.',
        ),
        _buildDocBullet(
          context,
          'clear_cell',
          'Efface le contenu d’une cellule ciblée.',
        ),
        _buildDocBullet(
          context,
          'run_snippet',
          'Exécute un snippet défini dans un module partagé (paramètres : module, name, args?).',
        ),
        const SizedBox(height: 16),
        Text('Contexte disponible', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          'Les templates peuvent accéder aux informations du classeur : {{workbook.pageCount}}, {{page.name}}, {{sheetKey}}… Utilisez ces variables pour créer des scripts dynamiques.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text('Exemple complet', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: codeBackground,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.4),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: SelectableText(
              'name: Exemple page\nscope: page\nhandlers:\n  - event: page.enter\n    actions:\n      - log:\n          message: "Bienvenue {{page.name}}"\n      - set_cell:\n          cell: A1\n          value: "=SUM(B1:B5)"\n',
              style: TextStyle(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Astuce : utilisez la bibliothèque de pré-code pour insérer un squelette d’actions avant de personnaliser votre script.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildDocBullet(
    BuildContext context,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$title : ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomActionsBar(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pré-code',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _customActions
              .map(
                (action) => Tooltip(
                  message: action.template,
                  preferBelow: false,
                  child: ActionChip(
                    label: Text(action.label),
                    onPressed: () => _handleInsertCustomAction(action),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  void _handleInsertCustomAction(CustomAction action) {
    final controller = _scriptEditorController;
    final selection = controller.selection;
    final insertion = action.template;
    final text = controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final newText = text.replaceRange(start, end, insertion);
    final newSelection = TextSelection.collapsed(
      offset: start + insertion.length,
    );
    _suppressScriptEditorChanges = true;
    controller.value = controller.value.copyWith(
      text: newText,
      selection: newSelection,
      composing: TextRange.empty,
    );
    _suppressScriptEditorChanges = false;
    if (!_scriptEditorDirty) {
      setState(() {
        _scriptEditorDirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _manager,
      builder: (context, _) {
        final workbook = _manager.workbook;
        final pages = workbook.pages;
        final activePageIndex = _manager.activePageIndex;

        final tabs = <WorkbookPageTabData>[];
        for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
          final page = pages[pageIndex];
          int? sheetIndex;
          if (page is Sheet) {
            final index = workbook.sheets.indexOf(page);
            if (index != -1) {
              sheetIndex = index;
            }
          }
          tabs.add(
            WorkbookPageTabData(
              title: page.name,
              pageIndex: pageIndex,
              icon: workbookPageIcon(page),
              sheetIndex: sheetIndex,
              canClose: page is Sheet && workbook.sheets.length > 1,
            ),
          );
        }

        final theme = Theme.of(context);
        final borderColor = theme.colorScheme.outline.withOpacity(0.15);

        final workbookColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CommandRibbon(
              commandManager: _manager,
              onBeforeCommand: _commitActiveSelectionEdits,
            ),
            WorkbookPageTabBar(
              tabs: tabs,
              selectedPageIndex: activePageIndex,
              onSelectPage: _handleSelectPage,
            ),
            Expanded(
              child: pages.isEmpty
                  ? const Center(child: Text('Aucune page disponible'))
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: pages.length,
                      onPageChanged: (index) {

                        final currentWorkbook = _manager.workbook;

                        if (_currentPageIndex >= 0 &&

                            _currentPageIndex < currentWorkbook.pages.length) {

                          final previousPage =

                              currentWorkbook.pages[_currentPageIndex];

                          unawaited(_runtime.dispatchPageLeave(previousPage));

                        }

                        _commitEditsForPage(currentWorkbook, _currentPageIndex);

                        _currentPageIndex = index;

                        if (index >= 0 && index < currentWorkbook.pages.length) {

                          final nextPage = currentWorkbook.pages[index];

                          unawaited(_runtime.ensurePageScript(nextPage));

                          unawaited(_runtime.dispatchPageEnter(nextPage));

                          if (_isAdmin &&
                              _scriptEditorScope == ScriptScope.page) {
                            _scriptEditorPageName = nextPage.name;
                            unawaited(_loadScriptEditor());
                          }

                        }

                        _manager.setActivePage(index);

                      },

                      itemBuilder: (context, index) {
                        final page = pages[index];
                        if (page is Sheet) {
                          final selectionState =
                              _stateForSheet(workbook, page);
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FormulaBar(selectionState: selectionState),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface,
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .dividerColor
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SheetGrid(
                                        selectionState: selectionState,
                                        rowCount: page.rowCount,
                                        columnCount: page.columnCount,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        if (page is MenuPage) {
                          return MenuPageView(

                            page: page,

                            workbook: workbook,

                            onOpenPage: _handleSelectPage,

                            onCreateSheet: _handleAddSheet,

                            onCreateNotes: _handleAddNotesPage,

                            onRemovePage: _handleRemovePage,

                            canRemovePage: (index) => _canRemovePage(workbook, index),

                            enableEditing: _isAdmin,

                          );

                        }
                        if (page is NotesPage) {
                          final controller =
                              _controllerForNotesPage(page);
                          return NotesPageView(
                            page: page,
                            controller: controller,
                          );
                        }
                        return Center(
                          child: Text('Page inconnue : ${page.name}'),
                        );
                      },
                    ),
                  ),
          ],
        );

        final workbookSurface = Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: workbookColumn,
          ),
        );

        if (_isAdmin) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                        child: workbookSurface,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                        child: _buildAdminWorkspace(context),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: workbookSurface,
                    ),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 420,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: _buildAdminWorkspace(context),
                    ),
                  ),
                ],
              );
            },
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: workbookSurface,
        );
      },
    );
  }
}

Widget _buildScriptGroupHeader(BuildContext context, String title) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    child: Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
      ),
    ),
  );
}

Widget _buildScriptLibraryTile({
  required BuildContext context,
  required IconData icon,
  required String label,
  required String subtitle,
  required VoidCallback onTap,
  required bool selected,
  required bool hasContent,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final foreground =
      selected ? colorScheme.primary : theme.textTheme.bodyMedium?.color;
  final background =
      selected ? colorScheme.primary.withOpacity(0.08) : Colors.transparent;

  return ListTile(
    dense: true,
    onTap: onTap,
    selected: selected,
    selectedTileColor: background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Icon(icon, color: foreground, size: 20),
    title: Text(
      label,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: foreground,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: theme.textTheme.bodySmall,
    ),
    trailing: Icon(
      hasContent ? Icons.check_circle : Icons.radio_button_unchecked,
      size: 16,
      color: hasContent ? colorScheme.primary : theme.disabledColor,
    ),
  );
}
