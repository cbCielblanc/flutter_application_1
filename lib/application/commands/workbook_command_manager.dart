import 'package:flutter/foundation.dart';

import '../../domain/workbook.dart';
import 'workbook_command.dart';

class WorkbookCommandManager extends ChangeNotifier {
  WorkbookCommandManager({required Workbook initialWorkbook})
      : _workbook = initialWorkbook;

  Workbook _workbook;
  int _activeSheetIndex = 0;

  Workbook get workbook => _workbook;
  int get activeSheetIndex => _activeSheetIndex;

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

  void execute(WorkbookCommand command) {
    final commandContext = context;
    if (!command.canExecute(commandContext)) {
      return;
    }

    final result = command.execute(commandContext);
    var shouldNotify = false;
    if (!identical(result.workbook, _workbook)) {
      _workbook = result.workbook;
      shouldNotify = true;
    }

    final desiredIndex = result.activeSheetIndex;
    if (desiredIndex != null && desiredIndex != _activeSheetIndex) {
      _activeSheetIndex = desiredIndex;
      shouldNotify = true;
    } else if (_activeSheetIndex >= _workbook.sheets.length) {
      _activeSheetIndex = _workbook.sheets.length - 1;
      shouldNotify = true;
    }

    if (shouldNotify) {
      notifyListeners();
    }
  }
}
