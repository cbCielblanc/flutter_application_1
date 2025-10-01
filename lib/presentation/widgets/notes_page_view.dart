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
            'Consignez vos idées ou informations importantes.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: TextField(
              controller: controller,
              expands: true,
              maxLines: null,
              minLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Saisissez vos notes...',
                alignLabelWithHint: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
