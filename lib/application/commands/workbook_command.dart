import 'package:flutter/foundation.dart';

import '../../domain/workbook.dart';
import '../../domain/sheet.dart';

/// Context passed to [WorkbookCommand]s to provide access to the current
/// workbook and metadata about the selection.
@immutable
class WorkbookCommandContext {
  const WorkbookCommandContext({
    required this.workbook,
    required this.activeSheetIndex,
  });

  final Workbook workbook;
  final int activeSheetIndex;

  /// Returns the active [Sheet] for the command, or `null` when the index is
  /// out of range.
  Sheet? get activeSheet {
    if (activeSheetIndex < 0 || activeSheetIndex >= workbook.sheets.length) {
      return null;
    }
    return workbook.sheets[activeSheetIndex];
  }

  bool get hasSheets => workbook.sheets.isNotEmpty;
}

/// Result returned after executing a [WorkbookCommand].
@immutable
class WorkbookCommandResult {
  const WorkbookCommandResult({
    required this.workbook,
    this.activeSheetIndex,
  });

  final Workbook workbook;
  final int? activeSheetIndex;
}

/// Base contract for all commands mutating the [Workbook].
abstract class WorkbookCommand {
  const WorkbookCommand();

  /// Human readable label used by ribbon buttons.
  String get label;

  /// Allows commands to be conditionally enabled.
  bool canExecute(WorkbookCommandContext context) => true;

  /// Executes the command and returns the resulting workbook state.
  WorkbookCommandResult execute(WorkbookCommandContext context);
}
