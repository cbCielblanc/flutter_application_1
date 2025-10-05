import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../state/sheet_selection_state.dart';

class SheetGrid extends StatefulWidget {
  const SheetGrid({
    super.key,
    required this.selectionState,
    this.rowCount = 50,
    this.columnCount = 26,
    this.cellWidth = 120,
    this.cellHeight = 44,
    this.onCellTap,
    this.onCellDoubleTap,
  });

  final SheetSelectionState selectionState;
  final int rowCount;
  final int columnCount;
  final double cellWidth;
  final double cellHeight;
  final ValueChanged<CellPosition>? onCellTap;
  final ValueChanged<CellPosition>? onCellDoubleTap;

  @override
  State<SheetGrid> createState() => _SheetGridState();
}

class _SheetGridState extends State<SheetGrid> {
  late final ScrollController _horizontalController;
  late final ScrollController _verticalController;
  late List<double> _columnWidths;
  late List<double> _rowHeights;

  static const double _rowHeightEpsilon = 0.5;

  SheetSelectionState get _selectionState => widget.selectionState;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
    _verticalController = ScrollController();
    _columnWidths = List<double>.filled(widget.columnCount, widget.cellWidth);
    _rowHeights = List<double>.filled(widget.rowCount, widget.cellHeight);
    _ensureInitialSelection();
  }

  @override
  void didUpdateWidget(covariant SheetGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionState != oldWidget.selectionState) {
      _ensureInitialSelection();
    }
    if (widget.columnCount != oldWidget.columnCount) {
      _syncColumnWidths(widget.columnCount, oldWidget.columnCount);
    }
    if (widget.rowCount != oldWidget.rowCount) {
      _syncRowHeights(widget.rowCount, oldWidget.rowCount);
    }
  }

  void _syncColumnWidths(int newCount, int oldCount) {
    if (_columnWidths.length == newCount) {
      return;
    }
    final next = List<double>.filled(newCount, widget.cellWidth);
    final copyCount = math.min(_columnWidths.length, next.length);
    for (var i = 0; i < copyCount; i++) {
      next[i] = _columnWidths[i].clamp(_minColumnWidth, _maxColumnWidth);
    }
    setState(() {
      _columnWidths = next;
    });
  }

  void _syncRowHeights(int newCount, int oldCount) {
    if (_rowHeights.length == newCount) {
      return;
    }
    final next = List<double>.filled(newCount, widget.cellHeight);
    final copyCount = math.min(_rowHeights.length, next.length);
    for (var i = 0; i < copyCount; i++) {
      next[i] = _rowHeights[i].clamp(_minRowHeight, _maxRowHeight);
    }
    setState(() {
      _rowHeights = next;
    });
  }

  void _resizeColumn(int columnIndex, double delta) {
    if (columnIndex < 0 || columnIndex >= _columnWidths.length) {
      return;
    }
    setState(() {
      final next = (_columnWidths[columnIndex] + delta).clamp(
        _minColumnWidth,
        _maxColumnWidth,
      );
      _columnWidths[columnIndex] = next;
    });
  }

  void _resizeRow(int rowIndex, double delta) {
    if (rowIndex < 0 || rowIndex >= _rowHeights.length) {
      return;
    }
    setState(() {
      final next = (_rowHeights[rowIndex] + delta).clamp(
        _minRowHeight,
        _maxRowHeight,
      );
      _rowHeights[rowIndex] = next;
    });
  }

  void _handleRowHeightMeasured(int rowIndex, double height) {
    if (!mounted || rowIndex < 0 || rowIndex >= _rowHeights.length) {
      return;
    }
    final nextHeight = math.max(height, _minRowHeight);
    if ((_rowHeights[rowIndex] - nextHeight).abs() < _rowHeightEpsilon) {
      return;
    }
    setState(() {
      _rowHeights[rowIndex] = nextHeight;
    });
  }

  void _ensureInitialSelection() {
    if (_selectionState.activeCell == null &&
        widget.rowCount > 0 &&
        widget.columnCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _selectionState.selectCell(const CellPosition(0, 0));
      });
    }
  }

  void _handleCellTap(CellPosition position) {
    _selectionState.commitEditingValue();
    _selectionState.selectCell(position);
    final callback = widget.onCellTap;
    if (callback != null) {
      callback(position);
    }
  }

  void _handleCellDoubleTap(CellPosition position) {
    final callback = widget.onCellDoubleTap;
    if (callback != null) {
      callback(position);
    }
  }

  void _moveSelection(int rowDelta, int columnDelta) {
    _selectionState.moveSelection(
      rowCount: widget.rowCount,
      columnCount: widget.columnCount,
      rowDelta: rowDelta,
      columnDelta: columnDelta,
    );
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columnCount = widget.columnCount + 1; // extra column for row headers
    final rowCount = widget.rowCount + 1; // extra row for column headers

    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width:
              _columnWidths.fold<double>(0, (sum, width) => sum + width) +
              _headerColumnWidth,
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalController,
              scrollDirection: Axis.vertical,
              child: RepaintBoundary(
                child: Table(
                  border: TableBorder.symmetric(
                    inside: BorderSide(
                      color: theme.dividerColor.withOpacity(0.35),
                    ),
                    outside: BorderSide(
                      color: theme.dividerColor.withOpacity(0.45),
                    ),
                  ),
                  columnWidths: <int, TableColumnWidth>{
                    0: const FixedColumnWidth(_headerColumnWidth),
                    for (var i = 1; i < columnCount; i++)
                      i: FixedColumnWidth(_columnWidths[i - 1]),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: List<TableRow>.generate(rowCount, (rowIndex) {
                    return TableRow(
                      decoration: BoxDecoration(
                        color: rowIndex == 0
                            ? theme.colorScheme.surfaceContainerHighest
                                  .withOpacity(0.55)
                            : null,
                      ),
                      children: List<Widget>.generate(columnCount, (
                        columnIndex,
                      ) {
                        if (rowIndex == 0 && columnIndex == 0) {
                          return const _HeaderCell(content: '');
                        }
                        if (rowIndex == 0) {
                          final label = CellPosition.columnLabel(
                            columnIndex - 1,
                          );
                          return _ColumnHeaderCell(
                            label: label,
                            onResize: (delta) =>
                                _resizeColumn(columnIndex - 1, delta),
                          );
                        }
                        if (columnIndex == 0) {
                          return _RowHeaderCell(
                            label: rowIndex.toString(),
                            minHeight: _rowHeights[rowIndex - 1],
                            backgroundColor: theme
                                .colorScheme
                                .surfaceContainerHighest
                                .withOpacity(0.4),
                            onResize: (delta) =>
                                _resizeRow(rowIndex - 1, delta),
                          );
                        }

                        final position = CellPosition(
                          rowIndex - 1,
                          columnIndex - 1,
                        );
                        return _DataCell(
                          selectionState: _selectionState,
                          position: position,
                          minHeight: _rowHeights[rowIndex - 1],
                          onSelect: () => _handleCellTap(position),
                          onDoubleTap: () => _handleCellDoubleTap(position),
                          onMoveSelection: _moveSelection,
                          onRowHeightChanged: (height) =>
                              _handleRowHeightMeasured(rowIndex - 1, height),
                        );
                      }),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const double _headerColumnWidth = 56;
const double _headerHeight = 40;
const double _minColumnWidth = 70;
const double _maxColumnWidth = 420;
const double _minRowHeight = 28;
const double _maxRowHeight = 160;
const double _resizeHandleThickness = 12;

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.content,
    this.minHeight = _headerHeight,
    this.backgroundColor,
    this.alignment = Alignment.center,
    this.padding,
  });

  final String content;
  final double minHeight;
  final Color? backgroundColor;
  final Alignment alignment;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: alignment,
      constraints: BoxConstraints(minHeight: minHeight),
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color:
          backgroundColor ??
          theme.colorScheme.surfaceContainerHighest.withOpacity(0.55),
      child: Text(
        content,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ColumnHeaderCell extends StatelessWidget {
  const _ColumnHeaderCell({required this.label, required this.onResize});

  final String label;
  final ValueChanged<double> onResize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _headerHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: _HeaderCell(content: label)),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _resizeHandleThickness,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeLeftRight,
              onDragUpdate: (details) => onResize(details.delta.dx),
            ),
          ),
        ],
      ),
    );
  }
}

class _SizeReportingWidget extends StatefulWidget {
  const _SizeReportingWidget({
    required this.onSizeChanged,
    required this.child,
  });

  final ValueChanged<double> onSizeChanged;
  final Widget child;

  @override
  State<_SizeReportingWidget> createState() => _SizeReportingWidgetState();
}

class _SizeReportingWidgetState extends State<_SizeReportingWidget> {
  Size? _lastReportedSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_notifySize);
  }

  @override
  void didUpdateWidget(covariant _SizeReportingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_notifySize);
  }

  void _notifySize(Duration _) {
    if (!mounted) {
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }
    final size = renderObject.size;
    if (_lastReportedSize == size) {
      return;
    }
    _lastReportedSize = size;
    widget.onSizeChanged(size.height);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_notifySize);
    return widget.child;
  }
}

class _RowHeaderCell extends StatelessWidget {
  const _RowHeaderCell({
    required this.label,
    required this.minHeight,
    required this.backgroundColor,
    required this.onResize,
  });

  final String label;
  final double minHeight;
  final Color backgroundColor;
  final ValueChanged<double> onResize;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(height: minHeight),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _HeaderCell(
              content: label,
              minHeight: minHeight,
              backgroundColor: backgroundColor,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _resizeHandleThickness,
            child: _ResizeHandle(
              cursor: SystemMouseCursors.resizeUpDown,
              onDragUpdate: (details) => onResize(details.delta.dy),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.cursor, required this.onDragUpdate});

  final MouseCursor cursor;
  final ValueChanged<DragUpdateDetails> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanUpdate: onDragUpdate,
      child: MouseRegion(cursor: cursor, child: const SizedBox.expand()),
    );
  }
}

class _DataCell extends StatefulWidget {
  const _DataCell({
    required this.selectionState,
    required this.position,
    required this.minHeight,
    required this.onSelect,
    this.onDoubleTap,
    required this.onMoveSelection,
    required this.onRowHeightChanged,
  });

  final SheetSelectionState selectionState;
  final CellPosition position;
  final double minHeight;
  final VoidCallback onSelect;
  final VoidCallback? onDoubleTap;
  final void Function(int rowDelta, int columnDelta) onMoveSelection;
  final ValueChanged<double> onRowHeightChanged;

  @override
  State<_DataCell> createState() => _DataCellState();
}

class _DataCellState extends State<_DataCell> {
  late String _displayValue;
  late bool _isActive;
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  SheetSelectionState get _selectionState => widget.selectionState;

  @override
  void initState() {
    super.initState();
    _displayValue = _selectionState.valueFor(widget.position);
    _isActive = _selectionState.activeCell == widget.position;
    _controller = TextEditingController(text: _initialEditingValue);
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    _focusNode.addListener(_handleFocusChanged);
    _selectionState.addListener(_handleSelectionChanged);
  }

  String get _initialEditingValue {
    if (_isActive) {
      return _selectionState.editingValue;
    }
    return _selectionState.valueFor(widget.position);
  }

  @override
  void didUpdateWidget(covariant _DataCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionState != widget.selectionState) {
      oldWidget.selectionState.removeListener(_handleSelectionChanged);
      _selectionState.addListener(_handleSelectionChanged);
      _syncFromState(force: true);
    } else if (oldWidget.position != widget.position) {
      _syncFromState(force: true);
    }
  }

  @override
  void dispose() {
    _selectionState.removeListener(_handleSelectionChanged);
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleSelectionChanged() {
    if (!mounted) {
      return;
    }
    _syncFromState();
  }

  void _syncFromState({bool force = false}) {
    final nextValue = _selectionState.valueFor(widget.position);
    final nextIsActive = _selectionState.activeCell == widget.position;
    final editingValue = _selectionState.editingValue;

    final didChangeActive = force || nextIsActive != _isActive;
    final didChangeValue = force || nextValue != _displayValue;

    _displayValue = nextValue;
    _isActive = nextIsActive;

    if (nextIsActive) {
      if (_controller.text != editingValue) {
        _controller
          ..text = editingValue
          ..selection = TextSelection(
            baseOffset: 0,
            extentOffset: editingValue.length,
          );
      }
      if (didChangeActive && !_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
    } else {
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
      if (didChangeValue) {
        _controller
          ..text = nextValue
          ..selection = TextSelection.collapsed(offset: nextValue.length);
      }
    }

    if (didChangeActive || didChangeValue) {
      setState(() {});
    }
  }

  void _insertLineBreak() {
    final text = _controller.text;
    final selection = _controller.selection;
    int start = selection.isValid ? selection.start : text.length;
    int end = selection.isValid ? selection.end : text.length;

    if (start < 0) {
      start = text.length;
    }
    if (end < 0) {
      end = text.length;
    }
    if (start > text.length) {
      start = text.length;
    }
    if (end > text.length) {
      end = text.length;
    }
    if (end < start) {
      end = start;
    }

    final updated = text.replaceRange(start, end, '\n');
    _controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + 1),
    );
    _selectionState.updateEditingValue(updated);
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus && _isActive) {
      _selectionState.commitEditingValue();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final logicalKey = event.logicalKey;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final isShiftPressed =
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
    final isAltPressed =
        pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);

    if (logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (isAltPressed) {
        _insertLineBreak();
        return KeyEventResult.handled;
      }
      _selectionState.commitEditingValue();
      widget.onMoveSelection(isShiftPressed ? -1 : 1, 0);
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.tab) {
      _selectionState.commitEditingValue();
      widget.onMoveSelection(0, isShiftPressed ? -1 : 1);
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.arrowUp) {
      _selectionState.commitEditingValue();
      widget.onMoveSelection(-1, 0);
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.arrowDown) {
      _selectionState.commitEditingValue();
      widget.onMoveSelection(1, 0);
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_controller.selection.isCollapsed &&
          _controller.selection.baseOffset == 0) {
        _selectionState.commitEditingValue();
        widget.onMoveSelection(0, -1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (logicalKey == LogicalKeyboardKey.arrowRight) {
      final text = _controller.text;
      if (_controller.selection.isCollapsed &&
          _controller.selection.baseOffset == text.length) {
        _selectionState.commitEditingValue();
        widget.onMoveSelection(0, 1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (logicalKey == LogicalKeyboardKey.escape) {
      final original = _selectionState.valueFor(widget.position);
      _selectionState.updateEditingValue(original);
      _controller
        ..text = original
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: original.length,
        );
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }
    if (logicalKey == LogicalKeyboardKey.delete) {
      _controller.clear();
      _selectionState.updateEditingValue('');
      _selectionState.commitEditingValue();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleTextChanged(String value) {
    _selectionState.updateEditingValue(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = _isActive
        ? theme.colorScheme.primary
        : theme.dividerColor.withOpacity(0.35);
    final backgroundColor = _isActive
        ? theme.colorScheme.primary.withOpacity(0.08)
        : theme.colorScheme.surface;

    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        onTap: widget.onSelect,
        onDoubleTap: () {
          widget.onSelect();
          final callback = widget.onDoubleTap;
          if (callback != null) {
            callback();
          }
          if (!_focusNode.hasFocus) {
            _focusNode.requestFocus();
          }
        },
        child: _SizeReportingWidget(
          onSizeChanged: widget.onRowHeightChanged,
          child: Container(
            alignment: Alignment.topLeft,
            constraints: BoxConstraints(minHeight: widget.minHeight),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border.all(color: borderColor, width: _isActive ? 2 : 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: _isActive
                ? TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: false,
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                    style: theme.textTheme.bodyMedium,
                    onChanged: _handleTextChanged,
                    textAlignVertical: TextAlignVertical.top,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    minLines: 1,
                    maxLines: null,
                    textAlign: TextAlign.left,
                  )
                : Text(
                    _displayValue,
                    style: theme.textTheme.bodyMedium,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    maxLines: null,
                    textAlign: TextAlign.left,
                  ),
          ),
        ),
      ),
    );
  }
}
