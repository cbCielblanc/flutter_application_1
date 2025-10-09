part of 'workbook_navigator.dart';

class WorkbookNavigator extends StatefulWidget {
  const WorkbookNavigator({
    super.key,
    required this.commandManager,
    required this.scriptRuntime,
    required this.isAdmin,
  });

  final WorkbookCommandManager commandManager;
  final ScriptRuntime scriptRuntime;
  final bool isAdmin;

  @override
  State<WorkbookNavigator> createState() => _WorkbookNavigatorState();
}

class _WorkbookNavigatorState extends State<WorkbookNavigator>
    with _WorkbookPagesLogic, _ScriptTreeLogic, _ScriptEditorLogic {
  late PageController _pageController;
  final Map<String, SheetSelectionState> _selectionStates =
      <String, SheetSelectionState>{};
  final Map<String, TextEditingController> _notesControllers =
      <String, TextEditingController>{};
  final Map<String, VoidCallback> _notesListeners =
      <String, VoidCallback>{};
  final List<CustomAction> _customActions = <CustomAction>[];
  late final TextEditingController _customActionLabelController;
  late final TextEditingController _customActionTemplateController;
  final TextEditingController _sharedScriptKeyController =
      TextEditingController(text: 'shared_module');
  final List<ScriptEditorTab> _scriptEditorTabs = <ScriptEditorTab>[];
  int? _activeScriptTabIndex;
  ScriptScope _scriptEditorScope = ScriptScope.page;
  String? _scriptEditorPageName;
  String _scriptSharedKey = 'shared_module';
  bool _scriptEditorLoading = false;
  String? _scriptEditorStatus;
  ScriptDescriptor? _currentScriptDescriptor;
  bool _suppressScriptEditorChanges = false;
  bool _scriptEditorFullscreen = false;
  bool _scriptEditorSplitPreview = false;
  bool _adminWorkspaceVisible = true;
  WidgetBuilder? _scriptEditorOverlayBuilder;
  late int _currentPageIndex;
  final List<StoredScript> _scriptLibrary = <StoredScript>[];
  bool _scriptLibraryLoading = false;
  String? _scriptLibraryError;
  final List<_ScriptTreeNode> _scriptTreeNodes = <_ScriptTreeNode>[];
  final Map<String, bool> _scriptTreeExpanded = <String, bool>{};
  final Map<String, String?> _scriptTreeParents = <String, String?>{};
  final Set<String> _scriptTreeExpandableNodes = <String>{};
  String? _activeScriptNodeId;

  WorkbookCommandManager get _manager => widget.commandManager;
  ScriptRuntime get _runtime => widget.scriptRuntime;
  bool get _isAdmin => widget.isAdmin;

  @override
  void initState() {
    super.initState();
    _customActionLabelController = TextEditingController();
    _customActionTemplateController = TextEditingController();
    _sharedScriptKeyController.addListener(_handleSharedScriptKeyChanged);
    if (_isAdmin) {
      _adminWorkspaceVisible = true;
      _initialiseCustomActions();
      unawaited(refreshScriptLibrary());
    }
    final initialPageIndex = _manager.activePageIndex;
    final pages = _manager.workbook.pages;
    if (pages.isNotEmpty) {
      final safeIndex = initialPageIndex >= 0 && initialPageIndex < pages.length
          ? initialPageIndex
          : 0;
      _scriptEditorPageName = pages[safeIndex].name;
    }
    _currentPageIndex = initialPageIndex;
    _pageController = PageController(
      initialPage: initialPageIndex < 0 ? 0 : initialPageIndex,
    );
    _manager.addListener(_handleManagerChanged);
    _updateScriptTree(notify: false);
    if (_isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_loadScriptEditor());
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant WorkbookNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.commandManager != widget.commandManager) {
      oldWidget.commandManager.removeListener(_handleManagerChanged);
      final newIndex = widget.commandManager.activePageIndex;
      _currentPageIndex = newIndex;
      _pageController.dispose();
      _pageController = PageController(
        initialPage: newIndex < 0 ? 0 : newIndex,
      );
      widget.commandManager.addListener(_handleManagerChanged);
    }
    if (!oldWidget.isAdmin && widget.isAdmin) {
      if (!_adminWorkspaceVisible) {
        setState(() {
          _adminWorkspaceVisible = true;
        });
      }
      _initialiseCustomActions();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(refreshScriptLibrary());
        unawaited(_loadScriptEditor());
      });
      _updateScriptTree();
    }
    if (oldWidget.isAdmin && !widget.isAdmin) {
      _updateScriptTree();
    }
  }

  void _toggleAdminWorkspaceVisibility() {
    setState(() {
      _adminWorkspaceVisible = !_adminWorkspaceVisible;
    });
  }

  @override
  void dispose() {
    _manager.removeListener(_handleManagerChanged);
    _sharedScriptKeyController.removeListener(_handleSharedScriptKeyChanged);
    _pageController.dispose();
    for (final state in _selectionStates.values) {
      state.dispose();
    }
    _notesControllers.forEach((name, controller) {
      final listener = _notesListeners[name];
      if (listener != null) {
        controller.removeListener(listener);
      }
      controller.dispose();
    });
    _customActionLabelController.dispose();
    _customActionTemplateController.dispose();
    for (final tab in _scriptEditorTabs) {
      final listener = tab.listener;
      if (listener != null) {
        tab.controller.removeListener(listener);
      }
      tab.controller.dispose();
    }
    _sharedScriptKeyController.dispose();
    super.dispose();
  }

  void _handleManagerChanged() {
    final workbook = _manager.workbook;
    final sheets = workbook.sheets;
    final notesPages = workbook.pages.whereType<NotesPage>().toList();

    final removedSheets = _selectionStates.keys
        .where((name) => sheets.every((sheet) => sheet.name != name))
        .toList(growable: false);
    for (final sheet in removedSheets) {
      _selectionStates.remove(sheet)?.dispose();
    }

    final removedNotes = _notesControllers.keys
        .where((name) => notesPages.every((page) => page.name != name))
        .toList(growable: false);
    for (final noteName in removedNotes) {
      final controller = _notesControllers.remove(noteName);
      final listener = _notesListeners.remove(noteName);
      if (controller != null && listener != null) {
        controller.removeListener(listener);
      }
      controller?.dispose();
    }

    final newIndex = _manager.activePageIndex;
    if (newIndex != _currentPageIndex) {
      _commitEditsForPage(workbook, _currentPageIndex);
      _currentPageIndex = newIndex;
      _jumpToPage(newIndex);
    }
    if (_scriptEditorScope == ScriptScope.page) {
      final pageNames = workbook.pages.map((page) => page.name).toList();
      final currentSelection = _scriptEditorPageName;
      if (currentSelection == null || !pageNames.contains(currentSelection)) {
        final fallback = pageNames.isNotEmpty ? pageNames.first : null;
        if (fallback != currentSelection) {
          setState(() {
            _scriptEditorPageName = fallback;
          });
          if (_isAdmin && fallback != null) {
            unawaited(_loadScriptEditor());
          }
        }
      }
    }
    if (_isAdmin) {
      unawaited(_synchronisePageScriptsWithWorkbook(workbook));
      _updateScriptTree();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _manager,
      builder: (context, _) {
        final workbook = _manager.workbook;
        final pages = workbook.pages;
        final activePageIndex = _manager.activePageIndex;

        final tabs = <WorkbookPageTabData>[];
        for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
          final page = pages[pageIndex];
          int? sheetIndex;
          if (page is Sheet) {
            final index = workbook.sheets.indexOf(page);
            if (index != -1) {
              sheetIndex = index;
            }
          }
          tabs.add(
            WorkbookPageTabData(
              title: page.name,
              pageIndex: pageIndex,
              icon: workbookPageIcon(page),
              sheetIndex: sheetIndex,
              canClose: page is Sheet && workbook.sheets.length > 1,
            ),
          );
        }

        final theme = Theme.of(context);
        final borderColor = theme.colorScheme.outline.withOpacity(0.15);

        final workbookColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CommandRibbon(
              commandManager: _manager,
              onBeforeCommand: _commitActiveSelectionEdits,
            ),
            WorkbookPageTabBar(
              tabs: tabs,
              selectedPageIndex: activePageIndex,
              onSelectPage: _handleSelectPage,
            ),
            Expanded(
              child: pages.isEmpty
                  ? const Center(child: Text('Aucune page disponible'))
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: pages.length,
                      onPageChanged: (index) {
                        final currentWorkbook = _manager.workbook;

                        Sheet? previousSheet;
                        if (_currentPageIndex >= 0 &&
                            _currentPageIndex < currentWorkbook.pages.length) {
                          final previousPage =
                              currentWorkbook.pages[_currentPageIndex];
                          if (previousPage is Sheet) {
                            previousSheet = previousPage;
                          }
                          unawaited(_runtime.dispatchPageLeave(previousPage));
                        }

                        _commitEditsForPage(currentWorkbook, _currentPageIndex);

                        _currentPageIndex = index;

                        if (index >= 0 && index < currentWorkbook.pages.length) {
                          final nextPage = currentWorkbook.pages[index];
                          unawaited(_runtime.ensurePageScript(nextPage));
                          if (previousSheet != null) {
                            unawaited(
                              _runtime.dispatchWorksheetDeactivate(
                                sheet: previousSheet,
                                nextSheet: nextPage is Sheet ? nextPage : null,
                              ),
                            );
                          }
                          unawaited(_runtime.dispatchPageEnter(nextPage));
                          if (nextPage is Sheet) {
                            unawaited(
                              _runtime.dispatchWorksheetActivate(
                                sheet: nextPage,
                                previousSheet: previousSheet,
                              ),
                            );
                          }
                          if (_isAdmin && _scriptEditorScope == ScriptScope.page) {
                            _scriptEditorPageName = nextPage.name;
                            unawaited(_loadScriptEditor());
                          }
                        }

                        _manager.setActivePage(index);
                      },
                      itemBuilder: (context, index) {
                        final page = pages[index];
                        if (page is Sheet) {
                          final selectionState =
                              _stateForSheet(workbook, page);
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FormulaBar(
                                  selectionState: selectionState,
                                  onCommitAndAdvance: () {
                                    selectionState.moveSelection(
                                      rowCount: page.rowCount,
                                      columnCount: page.columnCount,
                                      rowDelta: 1,
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface,
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .dividerColor
                                            .withOpacity(0.4),
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SheetGrid(
                                        selectionState: selectionState,
                                        rowCount: page.rowCount,
                                        columnCount: page.columnCount,
                                        onCellTap: (position) {
                                          unawaited(
                                            _runtime
                                                .dispatchWorksheetBeforeSingleClick(
                                              sheet: page,
                                              position: position,
                                            ),
                                          );
                                        },
                                        onCellDoubleTap: (position) {
                                          unawaited(
                                            _runtime
                                                .dispatchWorksheetBeforeDoubleClick(
                                              sheet: page,
                                              position: position,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        if (page is MenuPage) {
                          return MenuPageView(
                            page: page,
                            workbook: workbook,
                            onOpenPage: _handleSelectPage,
                            onCreateSheet: _handleAddSheet,
                            onCreateNotes: _handleAddNotesPage,
                            onRemovePage: _handleRemovePage,
                            canRemovePage: (index) => _canRemovePage(workbook, index),
                            enableEditing: _isAdmin,
                          );
                        }
                        if (page is NotesPage) {
                          final controller =
                              _controllerForNotesPage(page);
                          return NotesPageView(
                            page: page,
                            controller: controller,
                          );
                        }
                        return Center(
                          child: Text('Page inconnue : ${page.name}'),
                        );
                      },
                    ),
            ),
          ],
        );

        final workbookSurface = Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: workbookColumn,
          ),
        );

        if (_isAdmin) {
          Widget buildWorkbookWithToggle({required bool expanded}) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.only(right: _kWorkspaceToggleTabWidth),
                  child: workbookSurface,
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: SafeArea(
                    minimum: const EdgeInsets.only(top: 24),
                    child: _buildWorkspaceToggleTab(
                      context: context,
                      expanded: expanded,
                      onPressed: () {
                        if (expanded) {
                          _handleExitScriptEditorFullscreen();
                        }
                        _toggleAdminWorkspaceVisibility();
                      },
                    ),
                  ),
                ),
              ],
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 1100;
              if (!_adminWorkspaceVisible) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: buildWorkbookWithToggle(expanded: false),
                );
              }
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                        child: buildWorkbookWithToggle(expanded: true),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                        child: _buildAdminWorkspace(context),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: buildWorkbookWithToggle(expanded: true),
                    ),
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 420,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: _buildAdminWorkspace(context),
                    ),
                  ),
                ],
              );
            },
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: workbookSurface,
        );
      },
    );
  }
}
