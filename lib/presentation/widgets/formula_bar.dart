import 'package:flutter/material.dart';

import '../../state/sheet_selection_state.dart';

class FormulaBar extends StatefulWidget {
  const FormulaBar({super.key, required this.selectionState});

  final SheetSelectionState selectionState;

  @override
  State<FormulaBar> createState() => _FormulaBarState();
}

class _FormulaBarState extends State<FormulaBar> {
  late final TextEditingController _controller;
  String? _lastCellLabel;
  bool _lastIsEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    widget.selectionState.addListener(_handleSelectionChanged);
    _syncController();
  }

  @override
  void didUpdateWidget(covariant FormulaBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionState != oldWidget.selectionState) {
      oldWidget.selectionState.removeListener(_handleSelectionChanged);
      widget.selectionState.addListener(_handleSelectionChanged);
      _syncController();
    }
  }

  @override
  void dispose() {
    widget.selectionState.removeListener(_handleSelectionChanged);
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
    final currentValue = widget.selectionState.editingValue;
    if (_controller.text != currentValue) {
      _controller
        ..text = currentValue
        ..selection = TextSelection.collapsed(offset: currentValue.length);
    }
    final selectionState = widget.selectionState;
    final newLabel = selectionState.activeCellLabel;
    final newIsEnabled = selectionState.activeCell != null;
    final shouldRebuild =
        newLabel != _lastCellLabel || newIsEnabled != _lastIsEnabled;
    _lastCellLabel = newLabel;
    _lastIsEnabled = newIsEnabled;
    if (shouldRebuild) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectionState = widget.selectionState;
    final cellLabel = selectionState.activeCellLabel ?? '--';
    final isEnabled = selectionState.activeCell != null;

    return Material(
      elevation: 1,
      borderRadius: BorderRadius.circular(8),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                cellLabel,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: isEnabled,
                decoration: const InputDecoration(
                  hintText: 'Saisissez une valeur ou une formule…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: selectionState.updateEditingValue,
                onSubmitted: (_) => selectionState.commitEditingValue(),
                onEditingComplete: selectionState.commitEditingValue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
