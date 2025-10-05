part of 'workbook_navigator.dart';

const double _kWorkspaceToggleTabWidth = 36;
const double _kWorkspaceToggleTabHeight = 48;
const String _kWorkspaceToggleTooltip =
    'Afficher/Masquer l’espace de développement';

extension _AdminWorkspaceView on _WorkbookNavigatorState {
  Widget _buildWorkspaceToggleTab({
    required BuildContext context,
    required bool expanded,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final icon = expanded
        ? Icons.arrow_forward_ios
        : Icons.arrow_back_ios_new;
    final foregroundColor = theme.colorScheme.primary;
    final backgroundColor = theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outlineVariant;

    return Semantics(
      button: true,
      label: _kWorkspaceToggleTooltip,
      child: Tooltip(
        message: _kWorkspaceToggleTooltip,
        child: SizedBox(
          width: _kWorkspaceToggleTabWidth,
          child: Align(
            alignment: Alignment.topRight,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: Container(
                  height: _kWorkspaceToggleTabHeight,
                  width: _kWorkspaceToggleTabWidth,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(icon, size: 14, color: foregroundColor),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
      fit: StackFit.expand,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Espace de développement',
                  style: theme.textTheme.titleMedium,
                ),
              ),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: SizedBox(
                              height: _kWorkspaceToggleTabHeight,
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: _buildWorkspaceToggleTab(
                                  context: context,
                                  expanded: true,
                                  onPressed: () {
                                    _handleExitScriptEditorFullscreen();
                                    _toggleAdminWorkspaceVisibility();
                                  },
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Espace de développement',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _handleExitScriptEditorFullscreen,
                            icon: const Icon(Icons.fullscreen_exit),
                            label: const Text('Quitter le plein écran'),
                          ),
                          const SizedBox(width: 12),
                          ...buildActionButtons(
                            includeFullscreenToggle: false,
                          ),
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
          'Les modules OptimaScript sont désormais écrits en Dart. Chaque fichier expose les callbacks nécessaires (onWorkbookOpen, onPageEnter, etc.) et reçoit un ScriptContext donnant accès à l’API hôte.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text('Callbacks Dart disponibles', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildDocBullet(
          context,
          'onWorkbookOpen',
          'Appelé lors de l’ouverture du classeur afin d’initialiser les données partagées.',
        ),
        _buildDocBullet(
          context,
          'onWorkbookClose',
          'Appelé à la fermeture du classeur pour libérer des ressources ou journaliser les actions.',
        ),
        _buildDocBullet(
          context,
          'onPageEnter',
          'Déclencheur exécuté lorsque l’utilisateur arrive sur une page du classeur.',
        ),
        _buildDocBullet(
          context,
          'onPageLeave',
          'Callback invoqué avant de quitter la page active.',
        ),
        _buildDocBullet(
          context,
          'onCellChanged',
          'Notifié lorsqu’une cellule est modifiée par l’utilisateur ou un script.',
        ),
        _buildDocBullet(
          context,
          'onSelectionChanged',
          'Appelé à chaque évolution de la sélection utilisateur.',
        ),
        _buildDocBullet(
          context,
          'onNotesChanged',
          'Déclenché lorsque le contenu d’une page de notes est édité.',
        ),
        const SizedBox(height: 16),
        Text('Points d’entrée principaux de context.api', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        _buildDocBullet(
          context,
          'context.api.workbook.sheetNames',
          'Liste les feuilles disponibles pour faciliter la navigation.',
        ),
        _buildDocBullet(
          context,
          'workbook.sheetByName(name) / sheetAt(index)',
          'Récupère une feuille de calcul de manière typée.',
        ),
        _buildDocBullet(
          context,
          'workbook.activateSheetByName(name)',
          'Active une feuille et déclenche la navigation correspondante.',
        ),
        _buildDocBullet(
          context,
          'SheetApi.cellByLabel("A1") / cellAt(row, column)',
          'Accède directement à une cellule cible.',
        ),
        _buildDocBullet(
          context,
          'CellApi.setValue(value) / clear()',
          'Écrit ou efface la valeur d’une cellule sans manipuler le classeur brut.',
        ),
        const SizedBox(height: 16),
        Text('ScriptContext & API hôte', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          'Le ScriptContext fournit l’accès à context.api ainsi qu’aux utilitaires pour dialoguer avec l’hôte (context.callHost). Utilisez-le pour journaliser, déclencher des actions UI ou orchestrer plusieurs feuilles sans exposer de variables globales implicites.',
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
              'import \'package:optimascript/api.dart\';\n\nFuture<void> onPageEnter(ScriptContext context) async {\n  final workbook = context.api.workbook;\n  final sheet = workbook.sheetByName(\'Synthèse\');\n  final cell = sheet?.cellByLabel(\'A1\');\n  if (cell != null) {\n    cell.setValue(\'Bonjour Optima !\');\n  }\n  await context.callHost(\'logMessage\', {\'message\': \'Page Synthèse initialisée\'});\n}\n',
              style: TextStyle(
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Astuce : utilisez la bibliothèque de pré-code pour insérer un squelette de module Dart avant de personnaliser vos callbacks.',
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
