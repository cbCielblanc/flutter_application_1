import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/application/commands/workbook_command.dart';
import 'package:flutter_application_1/application/commands/workbook_command_manager.dart';
import 'package:flutter_application_1/domain/sheet.dart';
import 'package:flutter_application_1/domain/workbook.dart';
import 'package:flutter_application_1/services/history_service.dart';

void main() {
  group('HistoryService', () {
    test('records executed commands and exposes undo/redo stacks', () {
      final history = HistoryService<String>();

      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);

      history.pushExecuted('cmd1');
      history.pushExecuted('cmd2');

      expect(history.executedCommands, equals(['cmd1', 'cmd2']));
      expect(history.undoneCommands, isEmpty);
      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);

      final undo = history.popUndo();
      expect(undo, 'cmd2');
      expect(history.executedCommands, equals(['cmd1']));
      expect(history.undoneCommands, equals(['cmd2']));
      expect(history.canRedo, isTrue);

      final redo = history.popRedo();
      expect(redo, 'cmd2');
      expect(history.executedCommands, equals(['cmd1', 'cmd2']));
      expect(history.undoneCommands, isEmpty);
      expect(history.canRedo, isFalse);
    });
  });

  group('WorkbookCommandManager undo/redo', () {
    late Workbook initialWorkbook;
    late Workbook updatedWorkbook;
    late HistoryService<WorkbookCommand> history;

    setUp(() {
      initialWorkbook = _buildWorkbook('Initial');
      updatedWorkbook = _buildWorkbook('Updated');
      history = HistoryService<WorkbookCommand>();
    });

    test('execute records command and undo restores previous workbook', () {
      final manager = WorkbookCommandManager(
        initialWorkbook: initialWorkbook,
        historyService: history,
      );
      final command = _ReplaceWorkbookCommand(updatedWorkbook);

      final changed = manager.execute(command);
      expect(changed, isTrue);
      expect(manager.workbook, same(updatedWorkbook));
      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);

      manager.undo();
      expect(manager.workbook, same(initialWorkbook));
      expect(manager.canUndo, isFalse);
      expect(manager.canRedo, isTrue);

      manager.redo();
      expect(manager.workbook, same(updatedWorkbook));
      expect(manager.canUndo, isTrue);
      expect(manager.canRedo, isFalse);
    });
  });
}

Workbook _buildWorkbook(String value) {
  final sheet = Sheet.fromRows(
    name: 'Sheet 1',
    rows: [
      [value],
    ],
  );
  return Workbook(pages: [sheet]);
}

class _ReplaceWorkbookCommand extends WorkbookCommand {
  _ReplaceWorkbookCommand(this._replacement);

  final Workbook _replacement;

  @override
  String get label => 'Replace workbook';

  @override
  WorkbookCommandResult performExecute(WorkbookCommandContext context) {
    return WorkbookCommandResult(workbook: _replacement);
  }
}
