import 'package:flutter/foundation.dart';

import '../../domain/workbook.dart';
import '../../services/history_service.dart';
import 'workbook_command.dart';

class WorkbookCommandManager extends ChangeNotifier {
  WorkbookCommandManager({
    required Workbook initialWorkbook,
    HistoryService<WorkbookCommand>? historyService,
  })  : _workbook = initialWorkbook,
        _history = historyService ?? HistoryService<WorkbookCommand>();

  Workbook _workbook;
  int _activeSheetIndex = 0;
  final HistoryService<WorkbookCommand> _history;

  Workbook get workbook => _workbook;
  int get activeSheetIndex => _activeSheetIndex;
  bool get canUndo => _history.canUndo;
  bool get canRedo => _history.canRedo;
  HistoryService<WorkbookCommand> get history => _history;

  WorkbookCommandContext get context => WorkbookCommandContext(
        workbook: _workbook,
        activeSheetIndex: _activeSheetIndex,
      );

  void setActiveSheet(int index) {
    if (index == _activeSheetIndex) {
      return;
    }
    if (index < 0 || index >= _workbook.sheets.length) {
      return;
    }
    _activeSheetIndex = index;
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
    final previousWorkbook = _workbook;
    final previousIndex = _activeSheetIndex;
    if (!identical(result.workbook, _workbook)) {
      _workbook = result.workbook;
    }

    final desiredIndex = result.activeSheetIndex;
    if (desiredIndex != null && desiredIndex != _activeSheetIndex) {
      _activeSheetIndex = desiredIndex;
    } else if (_activeSheetIndex >= _workbook.sheets.length) {
      _activeSheetIndex = _workbook.sheets.length - 1;
    }

    final hasWorkbookChanged = !identical(previousWorkbook, _workbook);
    final hasIndexChanged = previousIndex != _activeSheetIndex;
    return hasWorkbookChanged || hasIndexChanged;
  }
}
