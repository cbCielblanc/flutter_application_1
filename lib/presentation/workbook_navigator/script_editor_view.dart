part of 'workbook_navigator.dart';

extension _ScriptEditorView on _WorkbookNavigatorState {
  Widget _buildScriptEditorSurface({
    required BuildContext context,
    required CodeThemeData codeTheme,
    required LineNumberStyle lineNumberStyle,
  }) {
    final theme = Theme.of(context);
    final borderDecoration = BoxDecoration(
      border: Border.all(
        color: theme.colorScheme.outline.withOpacity(0.25),
      ),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    );

    final activeTab = _activeScriptTab;
    final controller = activeTab?.controller;
    final isMutable = activeTab?.isMutable ?? false;

    Widget buildEditorField() {
      if (controller == null) {
        return DecoratedBox(
          decoration: borderDecoration,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Ouvrez un script depuis la bibliothèque pour commencer.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }

      final field = CodeTheme(
        data: codeTheme,
        child: DecoratedBox(
          decoration: borderDecoration,
          child: Stack(
            children: [
              Positioned.fill(
                child: TopAlignedCodeField(
                  controller: controller,
                  expands: true,
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  lineNumberStyle: lineNumberStyle,
                  padding: const EdgeInsets.all(12),
                  background: theme.colorScheme.surface,
                  textAlignVertical: TextAlignVertical.top,
                  readOnly: !isMutable,
                ),
              ),
              if (_scriptEditorLoading)
                const Positioned(
                  top: 16,
                  right: 16,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      );

      return field;
    }

    final editor = buildEditorField();

    Widget buildPreview() {
      return DecoratedBox(
        decoration: borderDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Aperçu (lecture seule)',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  controller?.text ?? '',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!_scriptEditorSplitPreview) {
      return editor;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: editor),
              const SizedBox(width: 12),
              Expanded(child: buildPreview()),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: editor),
            const SizedBox(height: 12),
            SizedBox(height: 160, child: buildPreview()),
          ],
        );
      },
    );
  }

  Widget _buildScriptTabChip(
    BuildContext context, {
    required ScriptEditorTab tab,
    required bool isActive,
    required VoidCallback onSelect,
    required VoidCallback onClose,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = _tabTitle(tab);
    final displayTitle = tab.isDirty ? '$title*' : title;
    final backgroundColor = isActive
        ? colorScheme.primary.withOpacity(0.12)
        : colorScheme.surfaceVariant.withOpacity(
            theme.brightness == Brightness.dark ? 0.35 : 0.25,
          );
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: isActive ? colorScheme.primary : null,
      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
    );

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onSelect,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(displayTitle, style: textStyle),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              tooltip: 'Fermer $title',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minHeight: 32, minWidth: 32),
              splashRadius: 18,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomActionsBar(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pré-code',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _customActions
              .map(
                (action) => Tooltip(
                  message: action.template,
                  preferBelow: false,
                  child: ActionChip(
                    label: Text(action.label),
                    onPressed: () => _handleInsertCustomAction(action),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
