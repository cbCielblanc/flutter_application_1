import 'dart:async';
import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:highlight/languages/yaml.dart';

import '../application/scripts/models.dart';
import '../application/scripts/runtime.dart';

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

class _WorkbookNavigatorState extends State<WorkbookNavigator> {
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
  late int _currentPageIndex;

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
    if (!_scriptEditorDirty) {
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

  void _handleScriptScopeChanged(ScriptScope scope) {
    if (_scriptEditorScope == scope) {
      return;
    }
    setState(() {
      _scriptEditorScope = scope;
      if (scope == ScriptScope.page) {
        final pages = _manager.workbook.pages;
        if (pages.isEmpty) {
          _scriptEditorPageName = null;
        } else if (!pages.any((page) => page.name == _scriptEditorPageName)) {
          _scriptEditorPageName = pages.first.name;
        }
      }
    });
    unawaited(_loadScriptEditor());
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

  String _scopeLabel(ScriptScope scope) {
    switch (scope) {
      case ScriptScope.global:
        return 'Global';
      case ScriptScope.page:
        return 'Page';
      case ScriptScope.shared:
        return 'Module partage';
    }
  }

  Widget _buildAdminPanel(BuildContext context) {
    final theme = Theme.of(context);
    final scope = _scriptEditorScope;
    final workbook = _manager.workbook;
    final pages = workbook.pages;
    final availableNames = pages.map((page) => page.name).toList(growable: false);
    final selectedPageName = availableNames.contains(_scriptEditorPageName)
        ? _scriptEditorPageName
        : (availableNames.isNotEmpty ? availableNames.first : null);
    final isDark = theme.brightness == Brightness.dark;
    final codeTheme = CodeThemeData(
      styles: isDark ? monokaiSublimeTheme : githubTheme,
    );
    final lineNumberStyle = LineNumberStyle(
      width: 48,
      textStyle: theme.textTheme.bodySmall,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Card(
        elevation: 2,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Administration des scripts',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Recharger tous les scripts',
                    onPressed: _scriptEditorLoading ? null : _handleReloadScripts,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<ScriptScope>(
                    value: scope,
                    onChanged: (value) {
                      if (value != null) {
                        _handleScriptScopeChanged(value);
                      }
                    },
                    items: ScriptScope.values
                        .map(
                          (value) => DropdownMenuItem<ScriptScope>(
                            value: value,
                            child: Text(_scopeLabel(value)),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  if (scope == ScriptScope.page)
                    DropdownButton<String>(
                      value: selectedPageName,
                      hint: const Text('Page'),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        if (value != _scriptEditorPageName) {
                          setState(() {
                            _scriptEditorPageName = value;
                          });
                          unawaited(_loadScriptEditor());
                        }
                      },
                      items: pages
                          .map(
                            (page) => DropdownMenuItem<String>(
                              value: page.name,
                              child: Text(page.name),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  if (scope == ScriptScope.shared)
                    SizedBox(
                      width: 240,
                      child: TextField(
                        controller: _sharedScriptKeyController,
                        decoration: InputDecoration(
                          labelText: 'Module partage',
                          helperText: 'Cle normalisee: $_scriptSharedKey',
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _scriptEditorLoading ? null : _loadScriptEditor,
                    icon: const Icon(Icons.download),
                    label: const Text('Charger'),
                  ),
                  FilledButton.icon(
                    onPressed: (_scriptEditorLoading || !_scriptEditorDirty)
                        ? null
                        : _handleSaveScript,
                    icon: const Icon(Icons.save),
                    label: Text(
                      _scriptEditorDirty ? 'Enregistrer*' : 'Enregistrer',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Contenu du script',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 240,
                child: CodeTheme(
                  data: codeTheme,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: const BorderRadius.all(Radius.circular(4)),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CodeField(
                            controller: _scriptEditorController,
                            expands: true,
                            textStyle: const TextStyle(fontFamily: 'monospace'),
                            lineNumberStyle: lineNumberStyle,
                            padding: const EdgeInsets.all(12),
                            background: theme.colorScheme.surface,
                          ),
                        ),
                        if (_scriptEditorLoading)
                          const Positioned(
                            top: 12,
                            right: 12,
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_scriptEditorStatus != null) ...[
                const SizedBox(height: 8),
                Text(
                  _scriptEditorStatus!,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomActionsBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _customActions
              .map(
                (action) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Tooltip(
                    message: action.template,
                    child: ActionChip(
                      label: Text(action.label),
                      onPressed: () => _handleInsertCustomAction(action),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
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

        return Column(
          children: [
            if (_isAdmin) _buildAdminPanel(context),
            if (_customActions.isNotEmpty) _buildCustomActionsBar(context),
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
      },
    );
  }
}
