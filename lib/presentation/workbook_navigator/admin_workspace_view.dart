part of 'workbook_navigator.dart';

extension _AdminWorkspaceView on _WorkbookNavigatorState {
  Widget _buildAdminWorkspace(BuildContext context) {
    final theme = Theme.of(context);
    final workbook = _manager.workbook;
    final pages = workbook.pages;
    final isDark = theme.brightness == Brightness.dark;
    final codeTheme = CodeThemeData(
      styles: isDark ? monokaiSublimeTheme : githubTheme,
    );
    final lineNumberStyle = LineNumberStyle(
      width: 48,
      textStyle: theme.textTheme.bodySmall,
    );
    final descriptor = _currentScriptDescriptor;
    final status = _scriptEditorStatus;
    final scriptFileName = descriptor?.fileName;
    final activeDescriptor = _descriptorForSelection() ?? descriptor;

    final editorLayout = _buildAdminEditorLayout(
      context: context,
      codeTheme: codeTheme,
      lineNumberStyle: lineNumberStyle,
      pages: pages,
      activeDescriptor: activeDescriptor,
      scriptFileName: scriptFileName,
      status: status,
    );

    final overlayBuilder = _scriptEditorOverlayBuilder ??
        (_) => const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: DefaultTabController(
            length: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  color: theme.colorScheme.surface,
                  child: TabBar(
                    labelColor: theme.colorScheme.primary,
                    indicatorColor: theme.colorScheme.primary,
                    tabs: const [
                      Tab(icon: Icon(Icons.code), text: 'Scripts'),
                      Tab(icon: Icon(Icons.menu_book_outlined), text: 'Documentation'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      editorLayout,
                      _buildAdminDocumentationTab(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _ScriptEditorOverlayHost(
          isActive: _adminWorkspaceVisible && _scriptEditorFullscreen,
          overlayBuilder: overlayBuilder,
        ),
      ],
    );
  }

  Widget _buildAdminEditorLayout({
    required BuildContext context,
    required CodeThemeData codeTheme,
    required LineNumberStyle lineNumberStyle,
    required List<WorkbookPage> pages,
    required ScriptDescriptor? activeDescriptor,
    required String? scriptFileName,
    required String? status,
  }) {
    final theme = Theme.of(context);
    final editorSurface = _buildScriptEditorSurface(
      context: context,
      codeTheme: codeTheme,
      lineNumberStyle: lineNumberStyle,
    );
    final activeTab = _activeScriptTab;
    final isDirty = activeTab?.isDirty ?? false;
    final isMutable = activeTab?.isMutable ?? false;

    Widget buildTabBar() {
      if (_scriptEditorTabs.isEmpty) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Aucun onglet ouvert. Sélectionnez un script dans la bibliothèque.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < _scriptEditorTabs.length; i++)
              Padding(
                padding: EdgeInsets.only(right: i == _scriptEditorTabs.length - 1 ? 0 : 8),
                child: _buildScriptTabChip(
                  context,
                  tab: _scriptEditorTabs[i],
                  isActive: i == _activeScriptTabIndex,
                  onSelect: () => _activateTab(i),
                  onClose: () => _handleCloseScriptTab(i),
                ),
              ),
          ],
        ),
      );
    }

    List<Widget> buildActionButtons({required bool includeFullscreenToggle}) {
      return [
        IconButton(
          tooltip:
              _scriptEditorSplitPreview ? 'Fermer la vue scindée' : 'Afficher la vue scindée',
          color: _scriptEditorSplitPreview ? theme.colorScheme.primary : null,
          onPressed: () {
            setState(() {
              _scriptEditorSplitPreview = !_scriptEditorSplitPreview;
            });
          },
          icon: const Icon(Icons.vertical_split),
        ),
        const SizedBox(width: 4),
        if (includeFullscreenToggle) ...[
          IconButton(
            tooltip: _scriptEditorFullscreen
                ? 'Quitter le plein écran'
                : 'Afficher en plein écran',
            color: _scriptEditorFullscreen ? theme.colorScheme.primary : null,
            onPressed: () {
              if (_scriptEditorFullscreen) {
                _handleExitScriptEditorFullscreen();
              } else {
                setState(() {
                  _scriptEditorFullscreen = true;
                });
              }
            },
            icon: Icon(
              _scriptEditorFullscreen
                  ? Icons.close_fullscreen
                  : Icons.open_in_full,
            ),
          ),
          const SizedBox(width: 4),
        ],
        IconButton(
          tooltip: 'Recharger tous les scripts',
          onPressed: _scriptEditorLoading ? null : _handleReloadScripts,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 4),
        FilledButton.icon(
          onPressed: (_scriptEditorLoading || !isDirty || !isMutable)
              ? null
              : _handleSaveScript,
          icon: const Icon(Icons.save_outlined),
          label: Text(
            isDirty ? 'Enregistrer*' : 'Enregistrer',
          ),
        ),
      ];
    }

    Widget buildEditorContent({required bool fullscreen}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildTabBar(),
          if (_scriptEditorTabs.isNotEmpty) const SizedBox(height: 8),
          if (scriptFileName != null)
            Text(
              'Fichier actuel : $scriptFileName',
              style: theme.textTheme.bodySmall,
            ),
          if (scriptFileName != null) const SizedBox(height: 8),
          if (_customActions.isNotEmpty) _buildCustomActionsBar(context),
          if (_customActions.isNotEmpty) const SizedBox(height: 12),
          if (fullscreen)
            Expanded(child: editorSurface)
          else
            Flexible(fit: FlexFit.tight, child: editorSurface),
          const SizedBox(height: 8),
          if (status != null)
            Text(
              status,
              style: theme.textTheme.bodySmall,
            ),
        ],
      );
    }

    final baseLayout = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Espace de développement',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  _handleExitScriptEditorFullscreen();
                  _toggleAdminWorkspaceVisibility();
                },
                icon: const Icon(Icons.visibility_off_outlined),
                label: const Text('Masquer'),
              ),
              const SizedBox(width: 12),
              ...buildActionButtons(includeFullscreenToggle: true),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_scriptEditorFullscreen) ...[
                SizedBox(
                  width: 240,
                  child: _buildScriptLibraryPanel(context),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: buildEditorContent(fullscreen: _scriptEditorFullscreen),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    _scriptEditorOverlayBuilder = (_) {
      return Positioned.fill(
        child: Theme(
          data: theme,
          child: DefaultTabController(
            length: 2,
            child: Scaffold(
              backgroundColor: theme.colorScheme.surface,
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Espace de développement',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              _handleExitScriptEditorFullscreen();
                              _toggleAdminWorkspaceVisibility();
                            },
                            icon: const Icon(Icons.visibility_off_outlined),
                            label: const Text('Masquer'),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _handleExitScriptEditorFullscreen,
                            icon: const Icon(Icons.fullscreen_exit),
                            label: const Text('Quitter le plein écran'),
                          ),
                          const SizedBox(width: 12),
                          ...buildActionButtons(includeFullscreenToggle: false),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Container(
                      color: theme.colorScheme.surface,
                      child: TabBar(
                        labelColor: theme.colorScheme.primary,
                        indicatorColor: theme.colorScheme.primary,
                        tabs: const [
                          Tab(icon: Icon(Icons.code), text: 'Scripts'),
                          Tab(
                            icon: Icon(Icons.menu_book_outlined),
                            text: 'Documentation',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: 240,
                                child: _buildScriptLibraryPanel(context),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                  child: buildEditorContent(fullscreen: true),
                                ),
                              ),
                            ],
                          ),
                          _buildAdminDocumentationTab(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    };

    return baseLayout;
  }

  Widget _buildAdminDocumentationTab(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final codeBackground = isDark
        ? theme.colorScheme.surfaceVariant.withOpacity(0.4)
        : theme.colorScheme.surfaceVariant;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Guide de référence rapide',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Text(
          'Les scripts Optima sont écrits en YAML. Chaque script définit un nom, une portée (global, page ou module partagé) et une liste de gestionnaires d’évènements.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text('Événements disponibles', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildDocBullet(
          context,
          'workbook.open',
          'Déclenché lors de l’ouverture du classeur.',
        ),
        _buildDocBullet(
          context,
          'workbook.close',
          'Déclenché à la fermeture du classeur.',
        ),
        _buildDocBullet(
          context,
          'page.enter',
          'Appelé quand un utilisateur arrive sur une page.',
        ),
        _buildDocBullet(
          context,
          'page.leave',
          'Appelé avant de quitter la page active.',
        ),
        _buildDocBullet(
          context,
          'cell.changed',
          'Notifié lorsqu’une cellule change de valeur.',
        ),
        _buildDocBullet(
          context,
          'selection.changed',
          'Notifié lorsqu’une sélection de cellules est modifiée.',
        ),
        _buildDocBullet(
          context,
          'notes.changed',
          'Déclenché lorsque le contenu d’une page de notes est édité.',
        ),
        const SizedBox(height: 16),
        Text('Actions supportées', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildDocBullet(
          context,
          'log',
          'Affiche un message dans la console des scripts. Utilisez le paramètre "message" pour personnaliser le texte.',
        ),
        _buildDocBullet(
          context,
          'set_cell',
          'Écrit une valeur dans une cellule (paramètres : cell, sheet?, value/raw). Les expressions sont évaluées après substitution des variables de contexte.',
        ),
        _buildDocBullet(
          context,
          'clear_cell',
          'Efface le contenu d’une cellule ciblée.',
        ),
        _buildDocBullet(
          context,
          'run_snippet',
          'Exécute un snippet défini dans un module partagé (paramètres : module, name, args?).',
        ),
        const SizedBox(height: 16),
        Text('Contexte disponible', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          'Les templates peuvent accéder aux informations du classeur : {{workbook.pageCount}}, {{page.name}}, {{sheetKey}}… Utilisez ces variables pour créer des scripts dynamiques.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text('Exemple complet', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: codeBackground,
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.4),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: SelectableText(
              'name: Exemple page\nscope: page\nhandlers:\n  - event: page.enter\n    actions:\n      - log:\n          message: "Bienvenue {{page.name}}"\n      - set_cell:\n          cell: A1\n          value: "=SUM(B1:B5)"\n',
              style: TextStyle(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Astuce : utilisez la bibliothèque de pré-code pour insérer un squelette d’actions avant de personnaliser votre script.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildDocBullet(
    BuildContext context,
    String title,
    String description,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$title : ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
