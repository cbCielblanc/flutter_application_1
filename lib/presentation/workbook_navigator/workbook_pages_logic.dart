part of 'workbook_navigator.dart';

mixin _WorkbookPagesLogic on State<WorkbookNavigator> {
  WorkbookCommandManager get _manager;
  ScriptRuntime get _runtime;
  PageController get _pageController;
  Map<String, SheetSelectionState> get _selectionStates;
  Map<String, TextEditingController> get _notesControllers;
  Map<String, VoidCallback> get _notesListeners;
  int get _currentPageIndex;

  SheetSelectionState _stateForSheet(Workbook workbook, Sheet sheet) {
    final state = _selectionStates.putIfAbsent(
      sheet.name,
      () => SheetSelectionState(
        onValuesChanged: (values) => _persistSheetValues(sheet.name, values),
      ),
    );
    state.onValuesChanged =
        (values) => _persistSheetValues(sheet.name, values);
    state.onCellValueChanged = (change) {
      unawaited(
        _runtime.dispatchCellChanged(sheet: sheet, change: change),
      );
    };
    state.onSelectionChanged = (change) {
      unawaited(
        _runtime.dispatchSelectionChanged(sheet: sheet, change: change),
      );
    };
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
}
