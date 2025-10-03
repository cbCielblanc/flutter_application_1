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
  });

  final List<WorkbookPageTabData> tabs;
  final int selectedPageIndex;
  final ValueChanged<int> onSelectPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.colorScheme.outline.withOpacity(0.2);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor)),
        color: theme.colorScheme.surface,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++) ...[
                _WorkbookTabButton(
                  tab: tabs[index],
                  isSelected: tabs[index].pageIndex == selectedPageIndex,
                  onSelect: () => onSelectPage(tabs[index].pageIndex),
                ),
                if (index != tabs.length - 1) const SizedBox(width: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbookTabButton extends StatelessWidget {
  const _WorkbookTabButton({
    required this.tab,
    required this.isSelected,
    required this.onSelect,
  });

  final WorkbookPageTabData tab;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground =
        isSelected ? colorScheme.primary : theme.textTheme.bodyMedium?.color;
    final background =
        isSelected ? colorScheme.primary.withOpacity(0.08) : Colors.transparent;
    final borderColor = isSelected
        ? colorScheme.primary.withOpacity(0.45)
        : colorScheme.outline.withOpacity(0.2);

    return Tooltip(
      message: tab.title,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 18, color: foreground),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  tab.title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
