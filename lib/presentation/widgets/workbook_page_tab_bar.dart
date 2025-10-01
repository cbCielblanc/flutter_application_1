import 'package:flutter/material.dart';

class WorkbookPageTabData {
  const WorkbookPageTabData({
    required this.title,
    required this.pageIndex,
    required this.icon,
    this.sheetIndex,
    this.canClose = false,
  });

  final String title;
  final int pageIndex;
  final IconData icon;
  final int? sheetIndex;
  final bool canClose;

  bool get isSheet => sheetIndex != null;
}

class WorkbookPageTabBar extends StatelessWidget {
  const WorkbookPageTabBar({
    super.key,
    required this.tabs,
    required this.selectedPageIndex,
    required this.onSelectPage,
    required this.onAddSheet,
    required this.onRemoveSheet,
  });

  final List<WorkbookPageTabData> tabs;
  final int selectedPageIndex;
  final ValueChanged<int> onSelectPage;
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
            for (final tab in tabs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InputChip(
                  avatar: Icon(tab.icon, size: 18),
                  label: Text(tab.title),
                  selected: tab.pageIndex == selectedPageIndex,
                  onPressed: () => onSelectPage(tab.pageIndex),
                  onDeleted: tab.canClose && tab.sheetIndex != null
                      ? () => onRemoveSheet(tab.sheetIndex!)
                      : null,
                  deleteIcon: const Icon(Icons.close, size: 18),
                  selectedColor: theme.colorScheme.primaryContainer,
                  showCheckmark: false,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter une feuille'),
                onPressed: onAddSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
