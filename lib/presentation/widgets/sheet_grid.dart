import 'package:flutter/material.dart';

import '../../state/sheet_selection_state.dart';

class SheetGrid extends StatefulWidget {
  const SheetGrid({
    super.key,
    required this.selectionState,
    this.rowCount = 50,
    this.columnCount = 26,
    this.cellWidth = 120,
    this.cellHeight = 44,
  });

  final SheetSelectionState selectionState;
  final int rowCount;
  final int columnCount;
  final double cellWidth;
  final double cellHeight;

  @override
  State<SheetGrid> createState() => _SheetGridState();
}

class _SheetGridState extends State<SheetGrid> {
  late final ScrollController _horizontalController;
  late final ScrollController _verticalController;

  @override
  void initState() {
    super.initState();
    _horizontalController = ScrollController();
    _verticalController = ScrollController();
    _ensureInitialSelection();
  }

  @override
  void didUpdateWidget(covariant SheetGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionState != oldWidget.selectionState) {
      _ensureInitialSelection();
    }
  }

  void _ensureInitialSelection() {
    if (widget.selectionState.activeCell == null &&
        widget.rowCount > 0 &&
        widget.columnCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        widget.selectionState.selectCell(const CellPosition(0, 0));
      });
    }
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
    final selectionState = widget.selectionState;
    final columnCount = widget.columnCount + 1; // extra column for row headers
    final rowCount = widget.rowCount + 1; // extra row for column headers

    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: widget.cellWidth * widget.columnCount + _headerColumnWidth,
          child: Scrollbar(
            controller: _verticalController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _verticalController,
              scrollDirection: Axis.vertical,
              child: RepaintBoundary(
                child: Table(
                  border: TableBorder.symmetric(
                    inside: BorderSide(color: theme.dividerColor.withOpacity(0.4)),
                    outside: BorderSide(color: theme.dividerColor.withOpacity(0.6)),
                  ),
                  columnWidths: <int, TableColumnWidth>{
                    0: const FixedColumnWidth(_headerColumnWidth),
                    for (var i = 1; i < columnCount; i++)
                      i: FixedColumnWidth(widget.cellWidth),
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: List<TableRow>.generate(rowCount, (rowIndex) {
                    return TableRow(
                      decoration: BoxDecoration(
                        color: rowIndex == 0
                            ? theme.colorScheme.surfaceVariant.withOpacity(0.6)
                            : null,
                      ),
                      children: List<Widget>.generate(columnCount, (columnIndex) {
                        if (rowIndex == 0 && columnIndex == 0) {
                          return _HeaderCell(
                            content: '',
                            backgroundColor:
                                theme.colorScheme.surfaceVariant.withOpacity(0.6),
                          );
                        }
                        if (rowIndex == 0) {
                          final label = CellPosition.columnLabel(columnIndex - 1);
                          return _HeaderCell(
                            content: label,
                            backgroundColor:
                                theme.colorScheme.surfaceVariant.withOpacity(0.6),
                          );
                        }
                        if (columnIndex == 0) {
                          return _HeaderCell(
                            content: rowIndex.toString(),
                            height: widget.cellHeight,
                            backgroundColor:
                                theme.colorScheme.surfaceVariant.withOpacity(0.4),
                          );
                        }
                        final position = CellPosition(rowIndex - 1, columnIndex - 1);
                        return _DataCell(
                          selectionState: selectionState,
                          position: position,
                          height: widget.cellHeight,
                          onTap: () {
                            selectionState.commitEditingValue();
                            selectionState.selectCell(position);
                          },
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

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.content,
    this.height = _headerHeight,
    this.backgroundColor,
  });

  final String content;
  final double height;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.center,
      height: height,
      color: backgroundColor ?? theme.colorScheme.surfaceVariant.withOpacity(0.6),
      child: Text(
        content,
        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DataCell extends StatefulWidget {
  const _DataCell({
    required this.selectionState,
    required this.position,
    required this.height,
    required this.onTap,
  });

  final SheetSelectionState selectionState;
  final CellPosition position;
  final double height;
  final VoidCallback onTap;

  @override
  State<_DataCell> createState() => _DataCellState();
}

class _DataCellState extends State<_DataCell> {
  late String _value;
  late bool _isActive;

  SheetSelectionState get _selectionState => widget.selectionState;

  @override
  void initState() {
    super.initState();
    _syncFromState();
    _selectionState.addListener(_handleSelectionChanged);
  }

  @override
  void didUpdateWidget(covariant _DataCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionState != widget.selectionState) {
      oldWidget.selectionState.removeListener(_handleSelectionChanged);
      _syncFromState();
      _selectionState.addListener(_handleSelectionChanged);
    } else if (oldWidget.position != widget.position) {
      _syncFromState();
    }
  }

  @override
  void dispose() {
    _selectionState.removeListener(_handleSelectionChanged);
    super.dispose();
  }

  void _syncFromState() {
    _value = _selectionState.valueFor(widget.position);
    _isActive = _selectionState.activeCell == widget.position;
  }

  void _handleSelectionChanged() {
    final nextValue = _selectionState.valueFor(widget.position);
    final nextIsActive = _selectionState.activeCell == widget.position;
    if (nextValue == _value && nextIsActive == _isActive) {
      return;
    }
    setState(() {
      _value = nextValue;
      _isActive = nextIsActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = _isActive
        ? theme.colorScheme.primary.withOpacity(0.1)
        : theme.colorScheme.surface;
    final borderColor = _isActive
        ? theme.colorScheme.primary
        : theme.dividerColor.withOpacity(0.4);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          height: widget.height,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: _isActive ? 2 : 1),
          ),
          child: Text(
            _value,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

const double _headerHeight = 40;
