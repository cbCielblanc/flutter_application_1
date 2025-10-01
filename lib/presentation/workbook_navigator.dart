import 'package:flutter/material.dart';

import '../application/commands/add_sheet_command.dart';
import '../application/commands/remove_sheet_command.dart';
import '../application/commands/workbook_command_manager.dart';
import '../domain/workbook.dart';
import '../state/sheet_selection_state.dart';
import 'widgets/command_ribbon.dart';
import 'widgets/formula_bar.dart';
import 'widgets/sheet_grid.dart';
import 'widgets/sheet_tab_bar.dart';

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
  late int _currentPageIndex;

  WorkbookCommandManager get _manager => widget.commandManager;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = _manager.activeSheetIndex;
    _pageController = PageController(initialPage: _currentPageIndex);
    _manager.addListener(_handleManagerChanged);
  }

  @override
  void didUpdateWidget(covariant WorkbookNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commandManager != widget.commandManager) {
      oldWidget.commandManager.removeListener(_handleManagerChanged);
      _currentPageIndex = widget.commandManager.activeSheetIndex;
      _pageController.dispose();
      _pageController = PageController(initialPage: _currentPageIndex);
      widget.commandManager.addListener(_handleManagerChanged);
    }
  }

  void _handleManagerChanged() {
    final workbook = _manager.workbook;
    final sheets = workbook.sheets;

    final removedSheets = _selectionStates.keys
        .where((name) => sheets.every((sheet) => sheet.name != name))
        .toList(growable: false);
    for (final sheet in removedSheets) {
      _selectionStates.remove(sheet)?.dispose();
    }

    final newIndex = _manager.activeSheetIndex;
    if (newIndex != _currentPageIndex) {
      if (_currentPageIndex >= 0 && _currentPageIndex < sheets.length) {
        _commitEditsForSheet(sheets[_currentPageIndex].name);
      }
      _currentPageIndex = newIndex;
      _jumpToSheet(newIndex);
    }
  }

  void _jumpToSheet(int index) {
    if (!_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pageController.jumpToPage(index);
        }
      });
      return;
    }
    if (_pageController.page?.round() == index) {
      return;
    }
    _pageController.animateToPage(
      index,
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
    super.dispose();
  }

  SheetSelectionState _stateForSheet(Workbook workbook, int sheetIndex) {
    final sheet = workbook.sheets[sheetIndex];
    final state =
        _selectionStates.putIfAbsent(sheet.name, SheetSelectionState.new);
    state.syncFromSheet(sheet);
    return state;
  }

  void _commitEditsForSheet(String sheetName) {
    final state = _selectionStates[sheetName];
    state?.commitEditingValue();
  }

  void _handleSelectSheet(int index) {
    final workbook = _manager.workbook;
    if (index < 0 || index >= workbook.sheets.length) {
      return;
    }
    if (_currentPageIndex >= 0 && _currentPageIndex < workbook.sheets.length) {
      _commitEditsForSheet(workbook.sheets[_currentPageIndex].name);
    }
    _manager.setActiveSheet(index);
  }

  void _handleAddSheet() {
    final workbook = _manager.workbook;
    if (_currentPageIndex >= 0 && _currentPageIndex < workbook.sheets.length) {
      _commitEditsForSheet(workbook.sheets[_currentPageIndex].name);
    }
    _manager.execute(AddSheetCommand());
  }

  void _handleRemoveSheet(int index) {
    final workbook = _manager.workbook;
    if (index < 0 || index >= workbook.sheets.length) {
      return;
    }
    final sheetName = workbook.sheets[index].name;
    _selectionStates.remove(sheetName)?.dispose();
    _manager.execute(RemoveSheetCommand(sheetIndex: index));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _manager,
      builder: (context, _) {
        final workbook = _manager.workbook;
        final sheets = workbook.sheets;

        return Column(
          children: [
            CommandRibbon(commandManager: _manager),
            SheetTabBar(
              sheets: [for (final sheet in sheets) sheet.name],
              selectedIndex: _manager.activeSheetIndex,
              onSelectSheet: _handleSelectSheet,
              onAddSheet: _handleAddSheet,
              onRemoveSheet: _handleRemoveSheet,
            ),
            Expanded(
              child: sheets.isEmpty
                  ? const Center(child: Text('Aucune feuille disponible'))
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: sheets.length,
                      onPageChanged: (index) {
                        final currentSheets = _manager.workbook.sheets;
                        if (_currentPageIndex >= 0 &&
                            _currentPageIndex < currentSheets.length) {
                          _commitEditsForSheet(
                              currentSheets[_currentPageIndex].name);
                        }
                        _currentPageIndex = index;
                        _manager.setActiveSheet(index);
                      },
                      itemBuilder: (context, index) {
                        final sheet = sheets[index];
                        final selectionState =
                            _stateForSheet(workbook, index);
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
                                    color:
                                        Theme.of(context).colorScheme.surface,
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
                                      rowCount: sheet.rowCount,
                                      columnCount: sheet.columnCount,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
