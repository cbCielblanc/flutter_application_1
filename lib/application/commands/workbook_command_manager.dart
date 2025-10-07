import 'package:flutter/foundation.dart';

import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import '../../domain/workbook_page.dart';
import '../../services/history_service.dart';
import 'workbook_command.dart';

class WorkbookCommandManager extends ChangeNotifier {
  WorkbookCommandManager({
    required Workbook initialWorkbook,
    HistoryService<WorkbookCommand>? historyService,
  })  : _workbook = initialWorkbook,
        _history = historyService ?? HistoryService<WorkbookCommand>();

  Workbook _workbook;
  int _activePageIndex = 0;
  int _workbookRevision = 0;
  final HistoryService<WorkbookCommand> _history;

  Workbook get workbook => _workbook;
  int get activePageIndex => _activePageIndex;
  int get workbookRevision => _workbookRevision;
  WorkbookPage? get activePage =>
      _workbook.pages.isEmpty ? null : _workbook.pages[_activePageIndex];
  int get activeSheetIndex {
    final page = activePage;
    if (page is Sheet) {
      final index = _workbook.sheets.indexOf(page);
      if (index != -1) {
        return index;
      }
    }
    return -1;
  }
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  HistoryService<WorkbookCommand> get history => _history;

  WorkbookCommandContext get context => WorkbookCommandContext(
        workbook: _workbook,
        activePageIndex: _activePageIndex,
      );

  void applyExternalUpdate(Workbook workbook, {int? activePageIndex}) {
    final result = WorkbookCommandResult(
      workbook: workbook,
      activePageIndex: activePageIndex ?? _activePageIndex,
    );
    final changed = _applyResult(result);
    if (changed) {
      notifyListeners();
    }
  }

  void setActiveSheet(int index) {
    if (index < 0 || index >= _workbook.sheets.length) {
      return;
    }
    final sheet = _workbook.sheets[index];
    final pageIndex = _workbook.pages.indexOf(sheet);
    if (pageIndex == -1) {
      return;
    }
    setActivePage(pageIndex);
  }

  void setActivePage(int index) {
    if (index == _activePageIndex) {
      return;
    }
    if (index < 0 || index >= _workbook.pages.length) {
      return;
    }
    _activePageIndex = index;
    notifyListeners();
  }

  bool execute(WorkbookCommand command, {bool recordHistory = true}) {
    final commandContext = context;
    if (!command.canExecute(commandContext)) {
      return false;
    }

    final result = command.execute(commandContext);
    final changed = _applyResult(result);
    if (recordHistory && changed) {
      _history.pushExecuted(command);
    }
    if (changed) {
      notifyListeners();
    }
    return changed;
  }

  void undo() {
    final command = _history.popUndo();
    if (command == null) {
      return;
    }

    final result = command.unexecute();
    _applyResult(result);
    notifyListeners();
  }

  void redo() {
    final command = _history.popRedo();
    if (command == null) {
      return;
    }

    final changed = execute(command, recordHistory: false);
    if (!changed) {
      notifyListeners();
    }
  }

  bool _applyResult(WorkbookCommandResult result) {
    final previousIndex = _activePageIndex;
    final hasWorkbookChanged = !identical(result.workbook, _workbook);
    if (hasWorkbookChanged) {
      _workbook = result.workbook;
      _workbookRevision++;
    }

    final desiredIndex = result.activePageIndex;
    if (desiredIndex != null && desiredIndex != _activePageIndex) {
      final maxIndex = _workbook.pages.length - 1;
      final boundedIndex = desiredIndex < 0
          ? 0
          : desiredIndex > maxIndex
              ? maxIndex
              : desiredIndex;
      _activePageIndex = boundedIndex;
    } else if (_activePageIndex >= _workbook.pages.length) {
      final maxIndex = _workbook.pages.length - 1;
      _activePageIndex = maxIndex < 0 ? 0 : maxIndex;
    }

    final hasIndexChanged = previousIndex != _activePageIndex;
    return hasWorkbookChanged || hasIndexChanged;
  }
}
