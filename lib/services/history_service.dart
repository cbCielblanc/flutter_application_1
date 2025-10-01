import 'package:meta/meta.dart';

/// Maintains an undo/redo history for command objects.
class HistoryService<TCommand> {
  HistoryService();

  final List<TCommand> _executedCommands = <TCommand>[];
  final List<TCommand> _undoneCommands = <TCommand>[];

  /// Clears both the executed and undone command stacks.
  @visibleForTesting
  void clear() {
    _executedCommands.clear();
    _undoneCommands.clear();
  }

  /// Records a freshly executed [command].
  void pushExecuted(TCommand command) {
    _executedCommands.add(command);
    _undoneCommands.clear();
  }

  /// Pops the last executed command for undoing.
  TCommand? popUndo() {
    if (_executedCommands.isEmpty) {
      return null;
    }
    final command = _executedCommands.removeLast();
    _undoneCommands.add(command);
    return command;
  }

  /// Pops the last undone command for re-execution.
  TCommand? popRedo() {
    if (_undoneCommands.isEmpty) {
      return null;
    }
    final command = _undoneCommands.removeLast();
    _executedCommands.add(command);
    return command;
  }

  /// Whether an undo operation can be performed.
  bool get canUndo => _executedCommands.isNotEmpty;

  /// Whether a redo operation can be performed.
  bool get canRedo => _undoneCommands.isNotEmpty;

  @visibleForTesting
  List<TCommand> get executedCommands =>
      List<TCommand>.unmodifiable(_executedCommands);

  @visibleForTesting
  List<TCommand> get undoneCommands =>
      List<TCommand>.unmodifiable(_undoneCommands);
}
