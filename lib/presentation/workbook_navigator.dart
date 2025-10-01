import 'package:flutter/material.dart';

import '../state/sheet_selection_state.dart';
import 'widgets/formula_bar.dart';
import 'widgets/sheet_grid.dart';
import 'widgets/sheet_tab_bar.dart';

class WorkbookNavigator extends StatefulWidget {
  const WorkbookNavigator({
    super.key,
    required this.sheets,
    required this.selectedSheetIndex,
    required this.onSheetSelected,
    required this.onAddSheet,
    required this.onRemoveSheet,
  });

  final List<String> sheets;
  final int selectedSheetIndex;
  final ValueChanged<int> onSheetSelected;
  final VoidCallback onAddSheet;
  final ValueChanged<int> onRemoveSheet;

  @override
  State<WorkbookNavigator> createState() => _WorkbookNavigatorState();
}

class _WorkbookNavigatorState extends State<WorkbookNavigator> {
  late final PageController _pageController;
  final Map<String, SheetSelectionState> _selectionStates =
      <String, SheetSelectionState>{};
  late int _currentPageIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.selectedSheetIndex);
    _currentPageIndex = widget.selectedSheetIndex;
  }

  @override
  void didUpdateWidget(covariant WorkbookNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSheetIndex != oldWidget.selectedSheetIndex) {
      _jumpToSheet(widget.selectedSheetIndex);
      _currentPageIndex = widget.selectedSheetIndex;
    }
    final removedSheets = oldWidget.sheets
        .where((sheet) => !widget.sheets.contains(sheet))
        .toList();
    for (final sheet in removedSheets) {
      _selectionStates.remove(sheet)?.dispose();
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
    _pageController.dispose();
    for (final state in _selectionStates.values) {
      state.dispose();
    }
    super.dispose();
  }

  SheetSelectionState _stateForSheet(String sheetName) {
    return _selectionStates.putIfAbsent(sheetName, SheetSelectionState.new);
  }

  void _commitEditsForSheet(String sheetName) {
    final state = _selectionStates[sheetName];
    state?.commitEditingValue();
  }

  void _handleSelectSheet(int index) {
    final sheets = widget.sheets;
    if (index < 0 || index >= sheets.length) {
      return;
    }
    if (_currentPageIndex >= 0 && _currentPageIndex < sheets.length) {
      _commitEditsForSheet(sheets[_currentPageIndex]);
    }
    widget.onSheetSelected(index);
  }

  void _handleAddSheet() {
    final sheets = widget.sheets;
    if (_currentPageIndex >= 0 && _currentPageIndex < sheets.length) {
      _commitEditsForSheet(sheets[_currentPageIndex]);
    }
    widget.onAddSheet();
  }

  void _handleRemoveSheet(int index) {
    final sheets = widget.sheets;
    if (index < 0 || index >= sheets.length) {
      return;
    }
    final sheetName = sheets[index];
    _selectionStates.remove(sheetName)?.dispose();
    widget.onRemoveSheet(index);
  }

  @override
  Widget build(BuildContext context) {
    final sheets = widget.sheets;
    return Column(
      children: [
        SheetTabBar(
          sheets: sheets,
          selectedIndex: widget.selectedSheetIndex,
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
                    if (_currentPageIndex >= 0 &&
                        _currentPageIndex < sheets.length) {
                      _commitEditsForSheet(sheets[_currentPageIndex]);
                    }
                    _currentPageIndex = index;
                    widget.onSheetSelected(index);
                  },
                  itemBuilder: (context, index) {
                    final sheetName = sheets[index];
                    final selectionState = _stateForSheet(sheetName);
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
                                color: Theme.of(context).colorScheme.surface,
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
  }
}
