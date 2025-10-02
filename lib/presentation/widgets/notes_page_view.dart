import 'package:flutter/material.dart';

import '../../domain/notes_page.dart';

class NotesPageView extends StatelessWidget {
  const NotesPageView({
    super.key,
    required this.page,
    required this.controller,
  });

  final NotesPage page;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            page.name,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Consignez vos idees ou informations importantes.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withOpacity(0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: controller,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: theme.textTheme.bodyMedium,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Saisissez vos notes...',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
