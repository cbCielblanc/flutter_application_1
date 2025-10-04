part of 'workbook_navigator.dart';

mixin _ScriptEditorLogic on State<WorkbookNavigator> {
  WorkbookCommandManager get _manager;
  ScriptRuntime get _runtime;
  bool get _isAdmin;
  List<CustomAction> get _customActions;
  TextEditingController get _sharedScriptKeyController;
  List<ScriptEditorTab> get _scriptEditorTabs;
  int? get _activeScriptTabIndex;
  set _activeScriptTabIndex(int? value);
  ScriptDescriptor? get _currentScriptDescriptor;
  set _currentScriptDescriptor(ScriptDescriptor? value);
  ScriptScope get _scriptEditorScope;
  set _scriptEditorScope(ScriptScope value);
  String? get _scriptEditorPageName;
  set _scriptEditorPageName(String? value);
  String get _scriptSharedKey;
  set _scriptSharedKey(String value);
  bool get _scriptEditorLoading;
  set _scriptEditorLoading(bool value);
  bool get _scriptEditorMutable;
  set _scriptEditorMutable(bool value);
  String? get _scriptEditorStatus;
  set _scriptEditorStatus(String? value);
  bool get _scriptEditorSplitPreview;
  set _scriptEditorSplitPreview(bool value);
  bool get _scriptEditorFullscreen;
  set _scriptEditorFullscreen(bool value);
  WidgetBuilder? get _scriptEditorOverlayBuilder;
  set _scriptEditorOverlayBuilder(WidgetBuilder? value);
  bool get _suppressScriptEditorChanges;
  set _suppressScriptEditorChanges(bool value);
  List<_ScriptTreeNode> get _scriptTreeNodes;
  Map<String, bool> get _scriptTreeExpanded;
  Map<String, String?> get _scriptTreeParents;
  String? get _activeScriptNodeId;
  set _activeScriptNodeId(String? value);

  Future<void> _refreshScriptLibrary({bool silent = false});
  void _expandAncestorsForId(
    String nodeId,
    Map<String, bool> expanded, {
    Map<String, String?>? parents,
  });
  String? _findNodeIdForDescriptor(
    List<_ScriptTreeNode> nodes,
    ScriptDescriptor descriptor,
  );
  ScriptDescriptor? _descriptorForSelection();
  bool _hasScriptDescriptor(ScriptDescriptor descriptor);

  ScriptEditorTab? get _activeScriptTab {
    final index = _activeScriptTabIndex;
    if (index == null || index < 0 || index >= _scriptEditorTabs.length) {
      return null;
    }
    return _scriptEditorTabs[index];
  }

  void _handleScriptEditorChanged(ScriptEditorTab tab) {
    if (_suppressScriptEditorChanges) {
      return;
    }
    if (!tab.isMutable) {
      return;
    }
    final isActive = identical(tab, _activeScriptTab);
    if (!tab.isDirty || (isActive && _scriptEditorSplitPreview)) {
      setState(() {
        tab.isDirty = true;
      });
    } else {
      tab.isDirty = true;
    }
  }

  void _handleSharedScriptKeyChanged() {
    final value = normaliseScriptKey(_sharedScriptKeyController.text);
    if (value != _scriptSharedKey) {
      setState(() {
        _scriptSharedKey = value;
      });
    }
    final activeTab = _activeScriptTab;
    if (activeTab != null &&
        activeTab.descriptor.scope == ScriptScope.shared) {
      activeTab.rawSharedKey = _sharedScriptKeyController.text;
    }
  }

  String _normaliseCustomActionTemplate(String template) {
    var value = template;
    if (value.startsWith('\n')) {
      value = value.substring(1);
    }
    if (!value.endsWith('\n')) {
      value = '$value\n';
    }
    return value;
  }

  void _initialiseCustomActions() {
    if (_customActions.isNotEmpty) {
      return;
    }
    _customActions.addAll(<CustomAction>[
      CustomAction(
        id: 'log',
        label: 'Ajouter un log',
        template: _normaliseCustomActionTemplate('''
  - log:
      message: "Votre message"
'''),
      ),
      CustomAction(
        id: 'set_cell',
        label: 'Ecrire une cellule',
        template: _normaliseCustomActionTemplate('''
  - set_cell:
      cell: A1
      value: "=B1"
'''),
      ),
      CustomAction(
        id: 'run_snippet',
        label: 'Executer un snippet',
        template: _normaliseCustomActionTemplate('''
  - run_snippet:
      module: shared/default
      name: votre_snippet
      args:
        target: A1
'''),
      ),
    ]);
  }

  int _indexOfTabForDescriptor(ScriptDescriptor descriptor) {
    return _scriptEditorTabs.indexWhere(
      (tab) =>
          tab.descriptor.scope == descriptor.scope &&
          tab.descriptor.key == descriptor.key,
    );
  }

  void _activateTab(
    int index, {
    Map<String, bool>? expandedOverride,
    String? resolvedNodeId,
    String? pageNameOverride,
    String? rawSharedKeyOverride,
  }) {
    if (index < 0 || index >= _scriptEditorTabs.length) {
      setState(() {
        _activeScriptTabIndex = null;
        _currentScriptDescriptor = null;
        _scriptEditorMutable = false;
        _scriptEditorStatus =
            'Selectionnez un script a charger pour commencer.';
        _activeScriptNodeId = null;
      });
      return;
    }

    final tab = _scriptEditorTabs[index];
    final descriptor = tab.descriptor;
    final updatedExpanded = Map<String, bool>.from(
      expandedOverride ?? _scriptTreeExpanded,
    );
    final parents = _scriptTreeParents;
    final nodeId =
        resolvedNodeId ?? _findNodeIdForDescriptor(_scriptTreeNodes, descriptor);
    if (nodeId != null) {
      _expandAncestorsForId(nodeId, updatedExpanded, parents: parents);
    }

    String? resolvedPageName = pageNameOverride ?? tab.pageName;
    if (descriptor.scope == ScriptScope.page && resolvedPageName == null) {
      for (final page in _manager.workbook.pages) {
        if (normaliseScriptKey(page.name) == descriptor.key) {
          resolvedPageName = page.name;
          break;
        }
      }
    }
    tab.pageName = resolvedPageName;

    String? resolvedRawSharedKey = rawSharedKeyOverride ?? tab.rawSharedKey;
    if (descriptor.scope == ScriptScope.shared) {
      resolvedRawSharedKey ??= descriptor.key;
      tab.rawSharedKey = resolvedRawSharedKey;
    }

    setState(() {
      _activeScriptTabIndex = index;
      _currentScriptDescriptor = descriptor;
      _scriptEditorScope = descriptor.scope;
      switch (descriptor.scope) {
        case ScriptScope.global:
          break;
        case ScriptScope.page:
          _scriptEditorPageName = resolvedPageName;
          break;
        case ScriptScope.shared:
          final rawValue = resolvedRawSharedKey ?? descriptor.key;
          _sharedScriptKeyController
              .removeListener(_handleSharedScriptKeyChanged);
          _sharedScriptKeyController.text = rawValue;
          _sharedScriptKeyController.selection =
              TextSelection.collapsed(offset: rawValue.length);
          _sharedScriptKeyController
              .addListener(_handleSharedScriptKeyChanged);
          _scriptSharedKey = normaliseScriptKey(rawValue);
          break;
      }
      _scriptTreeExpanded
        ..clear()
        ..addAll(updatedExpanded);
      _activeScriptNodeId = nodeId;
      _scriptEditorMutable = tab.isMutable;
      _scriptEditorStatus = tab.status;
    });
  }

  Future<void> _openOrFocusTab(
    ScriptDescriptor descriptor, {
    String? pageName,
    String? rawSharedKey,
    String? nodeId,
    Map<String, bool>? expanded,
  }) async {
    final resolvedRaw = descriptor.scope == ScriptScope.shared
        ? (rawSharedKey ?? descriptor.key)
        : null;
    final existingIndex = _indexOfTabForDescriptor(descriptor);
    if (existingIndex != -1) {
      final tab = _scriptEditorTabs[existingIndex];
      if (pageName != null) {
        tab.pageName = pageName;
      }
      if (resolvedRaw != null) {
        tab.rawSharedKey = resolvedRaw;
      }
      _activateTab(
        existingIndex,
        expandedOverride: expanded,
        resolvedNodeId: nodeId,
        pageNameOverride: pageName,
        rawSharedKeyOverride: resolvedRaw,
      );
      return;
    }

    final controller = CodeController(
      language: python,
      params: const EditorParams(tabSpaces: 2),
    );
    final tab = ScriptEditorTab(
      descriptor: descriptor,
      controller: controller,
      pageName: pageName,
      rawSharedKey: resolvedRaw,
      isDirty: false,
      isMutable: false,
    );
    final listener = () => _handleScriptEditorChanged(tab);
    tab.listener = listener;
    controller.addListener(listener);
    setState(() {
      _scriptEditorTabs.add(tab);
    });
    final newIndex = _scriptEditorTabs.length - 1;
    _activateTab(
      newIndex,
      expandedOverride: expanded,
      resolvedNodeId: nodeId,
      pageNameOverride: pageName,
      rawSharedKeyOverride: resolvedRaw,
    );
    await _loadTabSource(tab);
  }

  Future<void> _loadTabSource(ScriptEditorTab tab) async {
    setState(() {
      _scriptEditorLoading = true;
      if (identical(tab, _activeScriptTab)) {
        _scriptEditorStatus = 'Chargement de ${tab.descriptor.fileName}...';
      }
    });
    try {
      final storage = _runtime.storage;
      final existing = await storage.loadScript(tab.descriptor);
      StoredScript? stored = existing;
      var createdFromTemplate = false;
      if (stored == null && storage.supportsFileSystem) {
        final template = _defaultScriptTemplate(tab.descriptor);
        stored = await storage.saveScript(tab.descriptor, template);
        createdFromTemplate = true;
        debugPrint(
          'Script manquant pour ${tab.descriptor.fileName}. Modèle sauvegardé dans ${stored.origin}.',
        );
        await _refreshScriptLibrary(silent: true);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _currentScriptDescriptor = tab.descriptor;
        _suppressScriptEditorChanges = true;
        tab.controller.text = stored?.source ?? '';
        _suppressScriptEditorChanges = false;
        tab.isDirty = false;
        tab.isMutable = stored?.isMutable ?? false;
        if (stored == null) {
          tab.status = storage.supportsFileSystem
              ? 'Script introuvable pour ${tab.descriptor.fileName}.'
              :
                  'Script introuvable et édition indisponible sur cette plateforme (lecture seule).';
        } else if (!tab.isMutable) {
          tab.status =
              'Script chargé depuis ${stored.origin}. Edition indisponible sur cette plateforme (lecture seule).';
        } else {
          tab.status = createdFromTemplate
              ? 'Script absent. Modèle par défaut créé et sauvegardé (${stored.origin}).'
              : 'Script chargé depuis ${stored.origin}.';
        }
        if (identical(tab, _activeScriptTab)) {
          _scriptEditorMutable = tab.isMutable;
          _scriptEditorStatus = tab.status;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        final message = 'Erreur lors du chargement: $error';
        tab.status = message;
        if (identical(tab, _activeScriptTab)) {
          _scriptEditorStatus = message;
        }
      });
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _scriptEditorLoading = false;
      });
    }
  }

  String _tabTitle(ScriptEditorTab tab) {
    switch (tab.descriptor.scope) {
      case ScriptScope.global:
        return 'Global';
      case ScriptScope.page:
        return tab.pageName ?? tab.descriptor.key;
      case ScriptScope.shared:
        return tab.rawSharedKey ?? tab.descriptor.key;
    }
  }

  void _handleCloseScriptTab(int index) {
    if (index < 0 || index >= _scriptEditorTabs.length) {
      return;
    }
    final tab = _scriptEditorTabs[index];
    final listener = tab.listener;
    if (listener != null) {
      tab.controller.removeListener(listener);
    }
    tab.controller.dispose();

    int? nextActiveIndex = _activeScriptTabIndex;
    if (nextActiveIndex != null) {
      if (nextActiveIndex == index) {
        nextActiveIndex = null;
      } else if (nextActiveIndex > index) {
        nextActiveIndex -= 1;
      }
    }

    setState(() {
      _scriptEditorTabs.removeAt(index);
      _activeScriptTabIndex = nextActiveIndex;
    });

    if (_scriptEditorTabs.isEmpty) {
      setState(() {
        _currentScriptDescriptor = null;
        _scriptEditorMutable = false;
        _scriptEditorStatus =
            'Selectionnez un script a charger pour commencer.';
        _activeScriptNodeId = null;
      });
      return;
    }

    final targetIndex = nextActiveIndex ?? (index > 0 ? index - 1 : 0);
    _activateTab(targetIndex);
  }

  Future<void> _handleSaveScript() async {
    final activeTab = _activeScriptTab;
    if (activeTab == null) {
      setState(() {
        _scriptEditorStatus =
            "Impossible d'enregistrer: aucun script selectionne.";
      });
      return;
    }
    if (!activeTab.isMutable) {
      setState(() {
        _scriptEditorStatus =
            'Edition indisponible sur cette plateforme (lecture seule).';
      });
      return;
    }
    final descriptor = _resolveScriptDescriptor();
    if (descriptor == null) {
      setState(() {
        _scriptEditorStatus =
            "Impossible d'enregistrer: aucun script selectionne.";
      });
      return;
    }
    setState(() {
      _scriptEditorLoading = true;
      _scriptEditorStatus = 'Enregistrement du script...';
    });
    try {
      final stored =
          await _runtime.storage.saveScript(descriptor, activeTab.controller.text);
      await _runtime.reload();
      await _refreshScriptLibrary(silent: true);
      if (!mounted) {
        return;
      }
      setState(() {
        activeTab.descriptor = stored.descriptor;
        activeTab.isDirty = false;
        if (stored.descriptor.scope == ScriptScope.shared) {
          activeTab.rawSharedKey = _sharedScriptKeyController.text;
        }
        _currentScriptDescriptor = stored.descriptor;
        _scriptEditorStatus = 'Script enregistre dans ${stored.origin}.';
        activeTab.status = _scriptEditorStatus;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        final message =
            "Erreur lors de l'enregistrement du script: $error";
        _scriptEditorStatus = message;
        activeTab.status = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _scriptEditorLoading = false;
        });
      }
    }
  }

  Future<void> _handleReloadScripts() async {
    try {
      setState(() {
        _scriptEditorStatus = 'Rechargement des scripts...';
      });
      await _runtime.reload();
      await _refreshScriptLibrary(silent: true);
      final activeTab = _activeScriptTab;
      if (activeTab != null) {
        await _loadTabSource(activeTab);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scriptEditorStatus = 'Erreur lors du rechargement: $error';
      });
    }
  }

  ScriptDescriptor? _resolveScriptDescriptor() {
    switch (_scriptEditorScope) {
      case ScriptScope.global:
        return const ScriptDescriptor(scope: ScriptScope.global, key: 'default');
      case ScriptScope.page:
        final pageName = _scriptEditorPageName ??
            (_manager.workbook.pages.isNotEmpty
                ? _manager.workbook.pages.first.name
                : null);
        if (pageName == null) {
          return null;
        }
        return ScriptDescriptor(
          scope: ScriptScope.page,
          key: normaliseScriptKey(pageName),
        );
      case ScriptScope.shared:
        final raw = _sharedScriptKeyController.text.trim();
        if (raw.isEmpty && _scriptSharedKey.isEmpty) {
          return null;
        }
        final key = raw.isNotEmpty ? normaliseScriptKey(raw) : _scriptSharedKey;
        return ScriptDescriptor(scope: ScriptScope.shared, key: key);
    }
  }

  Future<void> _loadScriptEditor() async {
    final descriptor = _resolveScriptDescriptor();
    if (descriptor == null) {
      setState(() {
        _currentScriptDescriptor = null;
        _scriptEditorLoading = false;
        _scriptEditorMutable = false;
        _scriptEditorStatus =
            'Selectionnez un script a charger pour commencer.';
      });
      return;
    }
    final pageName =
        descriptor.scope == ScriptScope.page ? _scriptEditorPageName : null;
    final rawSharedKey = descriptor.scope == ScriptScope.shared
        ? _sharedScriptKeyController.text
        : null;
    await _openOrFocusTab(
      descriptor,
      pageName: pageName,
      rawSharedKey: rawSharedKey,
    );
  }

  String _defaultScriptTemplate(ScriptDescriptor descriptor) {
    switch (descriptor.scope) {
      case ScriptScope.global:
        return '"""Module global Optima."""\n\n'
            'def on_workbook_open(context):\n'
            '    """Déclenché lors de l\'ouverture du classeur."""\n'
            '    pass\n\n'
            'def on_page_enter(context):\n'
            '    """Déclenché lorsqu\'une page devient active."""\n'
            '    pass\n';
      case ScriptScope.page:
        return '"""Module spécifique à une page."""\n\n'
            'def on_page_enter(context):\n'
            '    """Personnalise l\'entrée sur la page."""\n'
            '    pass\n\n'
            'def on_cell_changed(context):\n'
            '    """Réagit à la modification d\'une cellule."""\n'
            '    pass\n';
      case ScriptScope.shared:
        return '"""Utilitaires Python partagés."""\n\n'
            'def helper(context, /, **kwargs):\n'
            '    """Fonction de démonstration accessible depuis d\'autres modules."""\n'
            '    pass\n';
    }
  }

  Future<void> _synchronisePageScriptsWithWorkbook(Workbook workbook) async {
    if (!_isAdmin) {
      return;
    }
    final createdPages = <String>[];
    for (final page in workbook.pages) {
      final descriptor = ScriptDescriptor(
        scope: ScriptScope.page,
        key: normaliseScriptKey(page.name),
      );
      if (_hasScriptDescriptor(descriptor)) {
        continue;
      }
      final existing = await _runtime.storage.loadScript(descriptor);
      if (existing != null) {
        continue;
      }
      final template = _defaultScriptTemplate(descriptor);
      final stored = await _runtime.storage.saveScript(descriptor, template);
      createdPages.add(page.name);
      debugPrint(
        'Script automatiquement créé pour la page "${page.name}" (${stored.origin}).',
      );
    }
    if (createdPages.isNotEmpty && mounted) {
      setState(() {
        final notice =
            'Scripts créés automatiquement pour: ${createdPages.join(', ')}.';
        _scriptEditorStatus =
            _scriptEditorStatus == null ? notice : '${_scriptEditorStatus!}\n$notice';
      });
    }
    await _refreshScriptLibrary(silent: true);
  }

  void _handleExitScriptEditorFullscreen() {
    if (!_scriptEditorFullscreen) {
      return;
    }
    setState(() {
      _scriptEditorFullscreen = false;
    });
  }

  void _handleInsertCustomAction(CustomAction action) {
    final tab = _activeScriptTab;
    if (tab == null) {
      return;
    }
    final controller = tab.controller;
    final selection = controller.selection;
    final insertion = action.template;
    final text = controller.text;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final newText = text.replaceRange(start, end, insertion);
    final newSelection = TextSelection.collapsed(
      offset: start + insertion.length,
    );
    _suppressScriptEditorChanges = true;
    controller.value = controller.value.copyWith(
      text: newText,
      selection: newSelection,
      composing: TextRange.empty,
    );
    _suppressScriptEditorChanges = false;
    if (!tab.isDirty || _scriptEditorSplitPreview) {
      setState(() {
        tab.isDirty = true;
      });
    } else {
      tab.isDirty = true;
    }
  }
}
