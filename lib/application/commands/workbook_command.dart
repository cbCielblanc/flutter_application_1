import 'package:flutter/foundation.dart';

import '../../domain/workbook.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook_page.dart';

/// Context passed to [WorkbookCommand]s to provide access to the current
/// workbook and metadata about the selection.
@immutable
class WorkbookCommandContext {
  const WorkbookCommandContext({
    required this.workbook,
    required this.activePageIndex,
  });

  final Workbook workbook;
  final int activePageIndex;

  /// Returns the active [WorkbookPage] for the command, or `null` when the
  /// index is out of range.
  WorkbookPage? get activePage {
    if (activePageIndex < 0 || activePageIndex >= workbook.pages.length) {
      return null;
    }
    return workbook.pages[activePageIndex];
  }

  /// Returns the active [Sheet] for the command, if the current page is a
  /// sheet.
  Sheet? get activeSheet => activePageAs<Sheet>();

  /// Returns the index of the active sheet within [Workbook.sheets], or `null`
  /// when the active page is not a sheet.
  int? get activeSheetIndex {
    final sheet = activeSheet;
    if (sheet == null) {
      return null;
    }
    final index = workbook.sheets.indexOf(sheet);
    return index == -1 ? null : index;
  }

  /// Retrieves the active page when it matches the requested [WorkbookPage]
  /// subtype.
  T? activePageAs<T extends WorkbookPage>() {
    final page = activePage;
    if (page is T) {
      return page;
    }
    return null;
  }

  /// Returns the page index for the provided [WorkbookPage] if it belongs to
  /// the workbook.
  int? pageIndexOf(WorkbookPage page) {
    final index = workbook.pages.indexOf(page);
    return index == -1 ? null : index;
  }

  bool get hasPages => workbook.pages.isNotEmpty;
  bool get hasSheets => workbook.sheets.isNotEmpty;
}

/// Result returned after executing a [WorkbookCommand].
@immutable
class WorkbookCommandResult {
  const WorkbookCommandResult({
    required this.workbook,
    this.activePageIndex,
  });

  final Workbook workbook;
  final int? activePageIndex;
}

/// Base contract for all commands mutating the [Workbook].
abstract class WorkbookCommand {
  WorkbookCommand();

  /// Human readable label used by ribbon buttons.
  String get label;

  /// Allows commands to be conditionally enabled.
  bool canExecute(WorkbookCommandContext context) => true;

  /// Executes the command and returns the resulting workbook state.
  WorkbookCommandResult execute(WorkbookCommandContext context) {
    _previousState = WorkbookCommandResult(
      workbook: context.workbook,
      activePageIndex: context.activePageIndex,
    );
    return performExecute(context);
  }

  /// Performs the actual mutation for the command.
  @protected
  WorkbookCommandResult performExecute(WorkbookCommandContext context);

  /// Reverts the command to its previous state.
  WorkbookCommandResult unexecute() {
    final previous = _previousState;
    if (previous == null) {
      throw StateError('Cannot unexecute a command that was never executed.');
    }
    return previous;
  }

  WorkbookCommandResult? _previousState;
}
