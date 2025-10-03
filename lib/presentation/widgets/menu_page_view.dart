import 'package:flutter/material.dart';

import '../../domain/menu_page.dart';
import '../../domain/workbook.dart';
import '../workbook_page_display.dart';

class MenuPageView extends StatelessWidget {
  const MenuPageView({
    super.key,
    required this.page,
    required this.workbook,
    required this.onOpenPage,
    required this.onCreateSheet,
    required this.onCreateNotes,
    required this.onRemovePage,
    required this.canRemovePage,
    required this.enableEditing,
  });

  final MenuPage page;
  final Workbook workbook;
  final ValueChanged<int> onOpenPage;
  final VoidCallback onCreateSheet;
  final VoidCallback onCreateNotes;
  final ValueChanged<int> onRemovePage;
  final bool Function(int pageIndex) canRemovePage;
  final bool enableEditing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final destinations = <_MenuDestination>[
      for (var index = 0; index < workbook.pages.length; index++)
        if (workbook.pages[index] is! MenuPage)
          _MenuDestination(
            title: workbook.pages[index].name,
            subtitle: workbookPageDescription(workbook.pages[index]),
            icon: workbookPageIcon(workbook.pages[index]),
            pageIndex: index,
            canRemove: canRemovePage(index),
          ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            page.name,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            "Retrouvez vos pages en un coup d'oeil.",
            style: theme.textTheme.bodyMedium,
          ),
          if (enableEditing) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onCreateSheet,
                  icon: const Icon(Icons.grid_on_outlined),
                  label: const Text('Nouvelle feuille'),
                ),
                OutlinedButton.icon(
                  onPressed: onCreateNotes,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Nouvelle page de notes'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: destinations.isEmpty
                ? Center(
                    child: Text(
                      'Aucune page disponible pour le moment.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: destinations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final destination = destinations[index];
                      return _MenuDestinationCard(
                        destination: destination,
                        onOpenPage: onOpenPage,
                        onRemovePage: onRemovePage,
                        enableEditing: enableEditing,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MenuDestination {
  const _MenuDestination({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.pageIndex,
    required this.canRemove,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int pageIndex;
  final bool canRemove;
}

class _MenuDestinationCard extends StatelessWidget {
  const _MenuDestinationCard({
    required this.destination,
    required this.onOpenPage,
    required this.onRemovePage,
    required this.enableEditing,
  });

  final _MenuDestination destination;
  final ValueChanged<int> onOpenPage;
  final ValueChanged<int> onRemovePage;
  final bool enableEditing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onOpenPage(destination.pageIndex),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                child: Icon(destination.icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            destination.title,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (enableEditing && destination.canRemove)
                          IconButton(
                            tooltip: 'Supprimer',
                            onPressed: () => onRemovePage(destination.pageIndex),
                            icon: const Icon(Icons.delete_outline),
                            splashRadius: 18,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      destination.subtitle,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

