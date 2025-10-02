import 'package:flutter/material.dart';

import '../../state/sheet_selection_state.dart';

class FormulaBar extends StatefulWidget {
  const FormulaBar({
    super.key,
    required this.selectionState,
    this.onCommitAndAdvance,
  });

  final SheetSelectionState selectionState;
  final VoidCallback? onCommitAndAdvance;

  @override
  State<FormulaBar> createState() => _FormulaBarState();
}

class _FormulaBarState extends State<FormulaBar> {
  late final TextEditingController _controller;
  String? _lastCellLabel;
  bool _lastIsEnabled = false;

  SheetSelectionState get _selectionState => widget.selectionState;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _selectionState.addListener(_handleSelectionChanged);
    _syncController();
  }

  @override
  void didUpdateWidget(covariant FormulaBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectionState != widget.selectionState) {
      oldWidget.selectionState.removeListener(_handleSelectionChanged);
      _selectionState.addListener(_handleSelectionChanged);
      _syncController();
    }
  }

  @override
  void dispose() {
    _selectionState.removeListener(_handleSelectionChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleSelectionChanged() {
    if (!mounted) {
      return;
    }
    _syncController();
  }

  void _syncController() {
    final currentValue = _selectionState.editingValue;
    if (_controller.text != currentValue) {
      _controller
        ..text = currentValue
        ..selection = TextSelection.collapsed(offset: currentValue.length);
    }
    final newLabel = _selectionState.activeCellLabel;
    final newIsEnabled = _selectionState.activeCell != null;
    final shouldRebuild =
        newLabel != _lastCellLabel || newIsEnabled != _lastIsEnabled;
    _lastCellLabel = newLabel;
    _lastIsEnabled = newIsEnabled;
    if (shouldRebuild) {
      setState(() {});
    }
  }

  void _commitAndAdvance() {
    widget.onCommitAndAdvance?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cellLabel = _selectionState.activeCellLabel ?? '--';
    final isEnabled = _selectionState.activeCell != null;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline.withOpacity(0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(cellLabel, style: theme.textTheme.labelLarge),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: isEnabled,
                decoration: const InputDecoration(
                  hintText: 'Valeur ou formule',
                  border: InputBorder.none,
                  isCollapsed: true,
                  isDense: true,
                ),
                minLines: 1,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                style: theme.textTheme.bodyMedium,
                onChanged: _selectionState.updateEditingValue,
                onSubmitted: (_) {
                  _selectionState.commitEditingValue();
                  _commitAndAdvance();
                },
                onEditingComplete: () {
                  _selectionState.commitEditingValue();
                },
              ),
            ),
            Tooltip(
              message: 'Valider',
              child: IconButton(
                icon: const Icon(Icons.check_circle_outline),
                splashRadius: 18,
                onPressed: isEnabled
                    ? () {
                        _selectionState.commitEditingValue();
                        _commitAndAdvance();
                      }
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
