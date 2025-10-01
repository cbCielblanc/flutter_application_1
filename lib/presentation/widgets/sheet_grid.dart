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
              child: AnimatedBuilder(
                animation: selectionState,
                builder: (context, _) {
                  return Table(
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
                          final value = selectionState.valueFor(position);
                          final isActive = selectionState.activeCell == position;
                          return _DataCell(
                            value: value,
                            isActive: isActive,
                            height: widget.cellHeight,
                            onTap: () {
                              selectionState.commitEditingValue();
                              selectionState.selectCell(position);
                            },
                          );
                        }),
                      );
                    }),
                  );
                },
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

class _DataCell extends StatelessWidget {
  const _DataCell({
    required this.value,
    required this.isActive,
    required this.height,
    required this.onTap,
  });

  final String value;
  final bool isActive;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isActive
        ? theme.colorScheme.primary.withOpacity(0.1)
        : theme.colorScheme.surface;
    final borderColor = isActive
        ? theme.colorScheme.primary
        : theme.dividerColor.withOpacity(0.4);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: isActive ? 2 : 1),
          ),
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

const double _headerHeight = 40;
