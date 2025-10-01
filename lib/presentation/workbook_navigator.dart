import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/commands/add_sheet_command.dart';
import '../application/commands/command_utils.dart';
import '../application/commands/remove_sheet_command.dart';
import '../application/commands/workbook_command_manager.dart';
import '../domain/cell.dart';
import '../domain/menu_page.dart';
import '../domain/notes_page.dart';
import '../domain/sheet.dart';
import '../domain/workbook.dart';
import '../state/sheet_selection_state.dart';
import 'widgets/command_ribbon.dart';
import 'widgets/formula_bar.dart';
import 'widgets/menu_page_view.dart';
import 'widgets/notes_page_view.dart';
import 'widgets/sheet_grid.dart';
import 'widgets/workbook_page_tab_bar.dart';
import 'workbook_page_display.dart';

class WorkbookNavigator extends StatefulWidget {
  const WorkbookNavigator({
    super.key,
    required this.commandManager,
  });

  final WorkbookCommandManager commandManager;

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
  late int _currentPageIndex;

  WorkbookCommandManager get _manager => widget.commandManager;

  @override
  void initState() {
    super.initState();
    final initialPageIndex = _manager.activePageIndex;
    _currentPageIndex = initialPageIndex;
    _pageController = PageController(
      initialPage: initialPageIndex < 0 ? 0 : initialPageIndex,
    );
    _manager.addListener(_handleManagerChanged);
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
    final pageIndex = workbook.pages.indexWhere((page) => page.name == pageName);
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
            CommandRibbon(
              commandManager: _manager,
              onBeforeCommand: _commitActiveSelectionEdits,
            ),
            WorkbookPageTabBar(
              tabs: tabs,
              selectedPageIndex: activePageIndex,
              onSelectPage: _handleSelectPage,
              onAddSheet: _handleAddSheet,
              onRemoveSheet: _handleRemoveSheet,
            ),
            Expanded(
              child: pages.isEmpty
                  ? const Center(child: Text('Aucune page disponible'))
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: pages.length,
                      onPageChanged: (index) {
                        final currentWorkbook = _manager.workbook;
                        _commitEditsForPage(currentWorkbook, _currentPageIndex);
                        _currentPageIndex = index;
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
