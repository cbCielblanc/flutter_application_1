part of 'workbook_navigator.dart';

mixin _ScriptTreeLogic on State<WorkbookNavigator> {
  bool get _isAdmin;
  ScriptRuntime get _runtime;
  WorkbookCommandManager get _manager;
  List<StoredScript> get _scriptLibrary;
  set _scriptLibraryLoading(bool value);
  set _scriptLibraryError(String? value);
  List<_ScriptTreeNode> get _scriptTreeNodes;
  Map<String, String?> get _scriptTreeParents;
  Set<String> get _scriptTreeExpandableNodes;
  Map<String, bool> get _scriptTreeExpanded;
  String? get _activeScriptNodeId;
  set _activeScriptNodeId(String? value);
  ScriptScope get _scriptEditorScope;
  String? get _scriptEditorPageName;
  String get _scriptSharedKey;

  Future<void> refreshScriptLibrary({bool silent = false}) async {
    if (!_isAdmin) {
      return;
    }
    if (!silent) {
      setState(() {
        _scriptLibraryLoading = true;
        _scriptLibraryError = null;
      });
    }
    try {
      final scripts = await _runtime.storage.loadAll();
      final warnings = _runtime.storage.migrationWarnings;
      if (!mounted) {
        return;
      }
      setState(() {
        _scriptLibrary
          ..clear()
          ..addAll(scripts);
        _scriptLibraryLoading = false;
        _scriptLibraryError = warnings.isEmpty ? null : warnings.join('\n');
      });
      _updateScriptTree();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scriptLibraryLoading = false;
        _scriptLibraryError = 'Erreur de chargement: $error';
      });
      _updateScriptTree();
    }
  }

  void _updateScriptTree({bool notify = true}) {
    if (!_isAdmin) {
      void clearData() {
        _scriptTreeNodes.clear();
        _scriptTreeParents.clear();
        _scriptTreeExpandableNodes.clear();
        _scriptTreeExpanded.clear();
        _activeScriptNodeId = null;
      }

      if (notify) {
        setState(clearData);
      } else {
        clearData();
      }
      return;
    }

    final result = _computeScriptTree();
    final descriptor = _descriptorForSelection();
    String? activeNodeId = _activeScriptNodeId;
    final newExpanded = <String, bool>{};
    for (final id in result.expandableIds) {
      if (_scriptTreeExpanded.containsKey(id)) {
        newExpanded[id] = _scriptTreeExpanded[id]!;
      } else {
        newExpanded[id] = true;
      }
    }

    if (descriptor != null) {
      final matchedId = _findNodeIdForDescriptor(result.nodes, descriptor);
      activeNodeId = matchedId;
      if (matchedId != null) {
        _expandAncestorsForId(
          matchedId,
          newExpanded,
          parents: result.parents,
        );
      }
    } else {
      activeNodeId = null;
    }

    void apply() {
      _scriptTreeNodes
        ..clear()
        ..addAll(result.nodes);
      _scriptTreeParents
        ..clear()
        ..addAll(result.parents);
      _scriptTreeExpandableNodes
        ..clear()
        ..addAll(result.expandableIds);
      _scriptTreeExpanded
        ..clear()
        ..addAll(newExpanded);
      _activeScriptNodeId = activeNodeId;
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  _ScriptTreeBuildResult _computeScriptTree() {
    final workbook = _manager.workbook;
    final pages = workbook.pages;
    final sharedScripts = _scriptLibrary
        .where((script) => script.descriptor.scope == ScriptScope.shared)
        .toList()
      ..sort((a, b) => a.descriptor.key.compareTo(b.descriptor.key));

    final globalDescriptor =
        const ScriptDescriptor(scope: ScriptScope.global, key: 'default');
    final globalHasScript = _hasScriptDescriptor(globalDescriptor);

    final nodes = <_ScriptTreeNode>[
      _ScriptTreeNode(
        id: 'group:workbook',
        label: 'Classeur',
        isGroup: true,
        children: [
          _ScriptTreeNode(
            id: 'script:global',
            label: 'Script global',
            subtitle: globalHasScript
                ? 'Script existant'
                : 'Déclenché pour tout le classeur',
            icon: Icons.language,
            descriptor: globalDescriptor,
            hasContent: globalHasScript,
          ),
        ],
      ),
      _ScriptTreeNode(
        id: 'group:pages',
        label: 'Pages',
        isGroup: true,
        emptyLabel: 'Aucune page disponible.',
        children: pages
            .map((page) {
              final descriptor = ScriptDescriptor(
                scope: ScriptScope.page,
                key: normaliseScriptKey(page.name),
              );
              final hasScript = _hasScriptDescriptor(descriptor);
              return _ScriptTreeNode(
                id: 'page:${descriptor.key}',
                label: page.name,
                subtitle: hasScript
                    ? 'Script existant'
                    : 'Créer un script pour cette page',
                icon: Icons.grid_on_outlined,
                descriptor: descriptor,
                pageName: page.name,
                hasContent: hasScript,
              );
            })
            .toList(growable: false),
      ),
      _ScriptTreeNode(
        id: 'group:shared',
        label: 'Modules partagés',
        isGroup: true,
        emptyLabel: 'Créez un module pour factoriser vos snippets.',
        children: sharedScripts
            .map((script) {
              final descriptor = script.descriptor;
              return _ScriptTreeNode(
                id: 'shared:${descriptor.key}',
                label: descriptor.key,
                subtitle: 'Module partagé',
                icon: Icons.extension,
                descriptor: descriptor,
                rawSharedKey: descriptor.key,
                hasContent: true,
              );
            })
            .toList(growable: false),
      ),
    ];

    final parents = <String, String?>{};
    final expandableIds = <String>{};

    void registerNodes(List<_ScriptTreeNode> list, {String? parent}) {
      for (final node in list) {
        parents[node.id] = parent;
        if (node.isGroup) {
          expandableIds.add(node.id);
        }
        if (node.children.isNotEmpty) {
          registerNodes(node.children, parent: node.id);
        }
      }
    }

    registerNodes(nodes);

    return _ScriptTreeBuildResult(
      nodes: nodes,
      parents: parents,
      expandableIds: expandableIds,
    );
  }

  void _expandAncestorsForId(
    String nodeId,
    Map<String, bool> expanded, {
    Map<String, String?>? parents,
  }) {
    final map = parents ?? _scriptTreeParents;
    var current = map[nodeId];
    while (current != null) {
      expanded[current] = true;
      current = map[current];
    }
  }

  String? _findNodeIdForDescriptor(
    List<_ScriptTreeNode> nodes,
    ScriptDescriptor descriptor,
  ) {
    for (final node in nodes) {
      final nodeDescriptor = node.descriptor;
      if (nodeDescriptor != null &&
          nodeDescriptor.scope == descriptor.scope &&
          nodeDescriptor.key == descriptor.key) {
        return node.id;
      }
      final childResult = _findNodeIdForDescriptor(node.children, descriptor);
      if (childResult != null) {
        return childResult;
      }
    }
    return null;
  }

  void _toggleScriptTreeExpansion() {
    if (_scriptTreeExpandableNodes.isEmpty) {
      return;
    }
    final hasCollapsed = _scriptTreeExpandableNodes
        .any((id) => !(_scriptTreeExpanded[id] ?? true));
    final target = hasCollapsed;
    setState(() {
      for (final id in _scriptTreeExpandableNodes) {
        _scriptTreeExpanded[id] = target;
      }
      if (!target && _activeScriptNodeId != null) {
        _expandAncestorsForId(_activeScriptNodeId!, _scriptTreeExpanded);
      }
    });
  }

  void _handleToggleScriptGroup(String nodeId) {
    final current = _scriptTreeExpanded[nodeId] ?? true;
    setState(() {
      _scriptTreeExpanded[nodeId] = !current;
    });
  }

  ScriptDescriptor? _descriptorForSelection() {
    switch (_scriptEditorScope) {
      case ScriptScope.global:
        return const ScriptDescriptor(scope: ScriptScope.global, key: 'default');
      case ScriptScope.page:
        final pageName = _scriptEditorPageName;
        if (pageName == null || pageName.isEmpty) {
          return null;
        }
        return ScriptDescriptor(
          scope: ScriptScope.page,
          key: normaliseScriptKey(pageName),
        );
      case ScriptScope.shared:
        if (_scriptSharedKey.isEmpty) {
          return null;
        }
        return ScriptDescriptor(scope: ScriptScope.shared, key: _scriptSharedKey);
    }
  }

  bool _hasScriptDescriptor(ScriptDescriptor descriptor) {
    return _scriptLibrary.any(
      (script) =>
          script.descriptor.scope == descriptor.scope &&
          script.descriptor.key == descriptor.key,
    );
  }

  Future<void> _handleSelectScriptDescriptor(
    ScriptDescriptor descriptor, {
    String? pageName,
    String? rawSharedKey,
    String? nodeId,
  }) async {
    final resolvedNodeId =
        nodeId ?? _findNodeIdForDescriptor(_scriptTreeNodes, descriptor);
    final expanded = Map<String, bool>.from(_scriptTreeExpanded);
    if (resolvedNodeId != null) {
      _expandAncestorsForId(resolvedNodeId, expanded);
    }
    String? resolvedPageName = pageName;
    if (descriptor.scope == ScriptScope.page && resolvedPageName == null) {
      for (final page in _manager.workbook.pages) {
        if (normaliseScriptKey(page.name) == descriptor.key) {
          resolvedPageName = page.name;
          break;
        }
      }
    }
    final resolvedRawSharedKey = descriptor.scope == ScriptScope.shared
        ? (rawSharedKey ?? descriptor.key)
        : null;
    await _openOrFocusTab(
      descriptor,
      pageName: resolvedPageName,
      rawSharedKey: resolvedRawSharedKey,
      nodeId: resolvedNodeId,
      expanded: expanded,
    );
  }

  Future<void> _promptNewSharedModule(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouveau module partagé'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nom du module',
              hintText: 'ex: automatisations',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Créer'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (result == null) {
      return;
    }
    final raw = result.trim();
    if (raw.isEmpty) {
      return;
    }
    final descriptor = ScriptDescriptor(
      scope: ScriptScope.shared,
      key: normaliseScriptKey(raw),
    );
    await _handleSelectScriptDescriptor(
      descriptor,
      rawSharedKey: raw,
    );
  }

  Future<void> _openOrFocusTab(
    ScriptDescriptor descriptor, {
    String? pageName,
    String? rawSharedKey,
    String? nodeId,
    Map<String, bool>? expanded,
  });
}
