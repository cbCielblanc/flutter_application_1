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
  });

  final MenuPage page;
  final Workbook workbook;
  final ValueChanged<int> onOpenPage;

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
          ),
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            page.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choisissez une page pour commencer. Mise en page : ${page.layout}.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: destinations.isEmpty
                ? Center(
                    child: Text(
                      'Aucune page à afficher pour le moment.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        for (final destination in destinations)
                          _MenuDestinationCard(
                            destination: destination,
                            onOpenPage: onOpenPage,
                          ),
                      ],
                    ),
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final int pageIndex;
}

class _MenuDestinationCard extends StatelessWidget {
  const _MenuDestinationCard({
    required this.destination,
    required this.onOpenPage,
  });

  final _MenuDestination destination;
  final ValueChanged<int> onOpenPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onOpenPage(destination.pageIndex),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    destination.icon,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        destination.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        destination.subtitle,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
