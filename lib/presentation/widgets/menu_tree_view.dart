import 'package:flutter/material.dart';

import '../../domain/menu_page.dart';
import '../../domain/workbook.dart';
import '../../domain/workbook_page.dart';
import '../workbook_page_display.dart';

class MenuTreeView extends StatelessWidget {
  const MenuTreeView({
    super.key,
    required this.page,
    required this.workbook,
    required this.onOpenPage,
    required this.onRemovePage,
    required this.canRemovePage,
    required this.enableEditing,
  });

  final MenuPage page;
  final Workbook workbook;
  final ValueChanged<int> onOpenPage;
  final ValueChanged<int> onRemovePage;
  final bool Function(int pageIndex) canRemovePage;
  final bool enableEditing;

  @override
  Widget build(BuildContext context) {
    if (page.tree.isEmpty) {
      return Center(
        child: Text(
          'Aucune entrée de menu définie pour le moment.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final node in page.tree.nodes) _buildNode(context, node, 0),
      ],
    );
  }

  Widget _buildNode(BuildContext context, MenuTreeNode node, int depth) {
    if (node.isLeaf) {
      return _buildLeaf(context, node, depth);
    }
    final children = node.children;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0, bottom: 12),
      child: Card(
        child: ExpansionTile(
          key: PageStorageKey<String>('menu-tree-${node.id}'),
          title: Text(
            node.label,
            style: theme.textTheme.titleMedium,
          ),
          childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
          children: [
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Aucun élément',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else
              for (final child in children)
                _buildNode(context, child, depth + 1),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaf(BuildContext context, MenuTreeNode node, int depth) {
    final resolved = _resolvePage(node.pageName);
    final theme = Theme.of(context);
    final padding = EdgeInsets.only(left: depth * 12.0, bottom: 12);
    if (resolved == null) {
      return Padding(
        padding: padding,
        child: Card(
          color: theme.colorScheme.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(
              'Page introuvable',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            subtitle: Text(
              "Impossible de trouver la page \"${node.pageName}\".",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ),
      );
    }

    final page = resolved.page;
    final pageIndex = resolved.index;
    final canRemove = canRemovePage(pageIndex);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: padding,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                child: Icon(
                  workbookPageIcon(page),
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      node.label.isEmpty ? page.name : node.label,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workbookPageDescription(page),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => onOpenPage(pageIndex),
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ouvrir'),
                  ),
                  if (enableEditing && canRemove)
                    IconButton(
                      tooltip: 'Supprimer',
                      onPressed: () => onRemovePage(pageIndex),
                      icon: const Icon(Icons.delete_outline),
                      splashRadius: 18,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  _ResolvedPage? _resolvePage(String? pageName) {
    if (pageName == null) {
      return null;
    }
    for (var index = 0; index < workbook.pages.length; index++) {
      final candidate = workbook.pages[index];
      if (candidate.name == pageName && candidate is! MenuPage) {
        return _ResolvedPage(page: candidate, index: index);
      }
    }
    return null;
  }
}

class _ResolvedPage {
  const _ResolvedPage({required this.page, required this.index});

  final WorkbookPage page;
  final int index;
}
