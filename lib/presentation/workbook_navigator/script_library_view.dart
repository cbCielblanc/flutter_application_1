part of 'workbook_navigator.dart';

extension _ScriptLibraryView on _WorkbookNavigatorState {
  Widget _buildScriptLibraryPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canToggle = _scriptTreeExpandableNodes.isNotEmpty;
    final hasCollapsed = _scriptTreeExpandableNodes
        .any((id) => !(_scriptTreeExpanded[id] ?? true));
    final toggleLabel = hasCollapsed ? 'Tout déplier' : 'Tout replier';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Bibliothèque de scripts',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (canToggle)
                TextButton.icon(
                  onPressed: _toggleScriptTreeExpansion,
                  icon: Icon(hasCollapsed ? Icons.unfold_more : Icons.unfold_less),
                  label: Text(toggleLabel),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _scriptLibraryLoading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: _scriptTreeNodes.length + 1,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == _scriptTreeNodes.length) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: OutlinedButton.icon(
                          onPressed: () => _promptNewSharedModule(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Nouveau module partagé'),
                        ),
                      );
                    }
                    final node = _scriptTreeNodes[index];
                    return _buildScriptTreeNode(context, node);
                  },
                ),
        ),
        if (_scriptLibraryError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              _scriptLibraryError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScriptTreeNode(
    BuildContext context,
    _ScriptTreeNode node, {
    int depth = 0,
  }) {
    final theme = Theme.of(context);
    final padding = EdgeInsets.only(left: 16.0 * depth + 16, right: 16);

    if (node.isGroup) {
      final expanded = _scriptTreeExpanded[node.id] ?? true;
      final children = node.children.isNotEmpty
          ? node.children
              .map(
                (child) => _buildScriptTreeNode(
                  context,
                  child,
                  depth: depth + 1,
                ),
              )
              .toList(growable: false)
          : <Widget>[];
      final placeholder = node.emptyLabel;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: padding,
            title: Text(
              node.label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => _handleToggleScriptGroup(node.id),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (children.isNotEmpty) ...children,
                        if (children.isEmpty && placeholder != null)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              16.0 * (depth + 1) + 16,
                              4,
                              16,
                              12,
                            ),
                            child: Text(
                              placeholder,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      );
    }

    final isSelected = _activeScriptNodeId == node.id;

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: padding,
      leading: node.icon != null ? Icon(node.icon, size: 20) : null,
      title: Text(node.label),
      subtitle: node.subtitle != null
          ? Text(
              node.subtitle!,
              style: theme.textTheme.bodySmall,
            )
          : null,
      trailing: node.hasContent
          ? Icon(
              Icons.check_circle,
              size: 16,
              color: theme.colorScheme.primary,
            )
          : null,
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primary.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: node.descriptor == null
          ? null
          : () => _handleSelectScriptDescriptor(
                node.descriptor!,
                pageName: node.pageName,
                rawSharedKey: node.rawSharedKey,
                nodeId: node.id,
              ),
    );
  }
}
