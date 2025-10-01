import 'package:flutter/material.dart';

class SheetTabBar extends StatelessWidget {
  const SheetTabBar({
    super.key,
    required this.sheets,
    required this.selectedIndex,
    required this.onSelectSheet,
    required this.onAddSheet,
    required this.onRemoveSheet,
  });

  final List<String> sheets;
  final int selectedIndex;
  final ValueChanged<int> onSelectSheet;
  final VoidCallback onAddSheet;
  final ValueChanged<int> onRemoveSheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            ...List.generate(sheets.length, (index) {
              final isSelected = index == selectedIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InputChip(
                  label: Text(sheets[index]),
                  selected: isSelected,
                  onPressed: () => onSelectSheet(index),
                  onDeleted:
                      sheets.length > 1 ? () => onRemoveSheet(index) : null,
                  deleteIcon: const Icon(Icons.close, size: 18),
                  selectedColor: theme.colorScheme.primaryContainer,
                  showCheckmark: false,
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
                onPressed: onAddSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
