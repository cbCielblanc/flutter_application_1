import 'dart:async';

import 'package:flutter/material.dart';

import 'application/commands/workbook_command_manager.dart';
import 'application/scripts/runtime.dart';
import 'application/scripts/storage.dart';
import 'domain/cell.dart';
import 'domain/menu_page.dart';
import 'domain/sheet.dart';
import 'domain/workbook.dart';
import 'services/workbook_storage.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/workbook_navigator/workbook_navigator.dart';

enum AppMode { user, admin }

extension AppModeLabel on AppMode {
  String get label => this == AppMode.user ? 'Utilisateur' : 'Administrateur';
  IconData get icon =>
      this == AppMode.user ? Icons.person_outline : Icons.admin_panel_settings;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final WorkbookStorage _workbookStorage = WorkbookStorage();
  ScriptRuntime? _scriptRuntime;
  WorkbookCommandManager? _commandManager;
  Future<void>? _saveOperation;
  AppMode _mode = AppMode.user;
  bool _isLoading = true;
  Object? _loadingError;

  @override
  void initState() {
    super.initState();
    unawaited(_initialiseApp());
  }

  @override
  void dispose() {
    _commandManager?.removeListener(_handleWorkbookChanged);
    _commandManager?.dispose();
    final runtime = _scriptRuntime;
    runtime?.detachNavigatorBinding();
    unawaited(runtime?.dispatchWorkbookClose() ?? Future.value());
    super.dispose();
  }

  Future<void> _initialiseApp() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingError = null;
      });
    }

    _commandManager?.removeListener(_handleWorkbookChanged);
    _commandManager?.dispose();
    final previousRuntime = _scriptRuntime;
    previousRuntime?.detachNavigatorBinding();
    unawaited(previousRuntime?.dispatchWorkbookClose() ?? Future.value());

    try {
      final loadedWorkbook = await _workbookStorage.load();
      final initialWorkbook = loadedWorkbook ?? _createInitialWorkbook();
      final commandManager =
          WorkbookCommandManager(initialWorkbook: initialWorkbook);
      _commandManager = commandManager;
      commandManager.addListener(_handleWorkbookChanged);

      final scriptStorage = ScriptStorage();
      final runtime =
          ScriptRuntime(storage: scriptStorage, commandManager: commandManager);
      _scriptRuntime = runtime;

      await runtime.initialize();
      await runtime.dispatchWorkbookOpen();

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadingError = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Failed to load workbook: $error\n$stackTrace');
      _commandManager?.removeListener(_handleWorkbookChanged);
      _commandManager?.dispose();
      _commandManager = null;
      _scriptRuntime = null;
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadingError = error;
      });
    }
  }

  void _updateMode(AppMode mode) {
    if (_mode == mode) {
      return;
    }
    setState(() => _mode = mode);
  }

  void _handleWorkbookChanged() {
    _queueSave();
  }

  Future<void> _queueSave({bool showFeedback = false, BuildContext? context}) {
    final operation = (_saveOperation ?? Future.value()).then((_) async {
      await _performSave(showFeedback: showFeedback, context: context);
    });
    _saveOperation = operation.whenComplete(() {
      if (identical(_saveOperation, operation)) {
        _saveOperation = null;
      }
    });
    return operation;
  }

  Future<void> _performSave({bool showFeedback = false, BuildContext? context}) async {
    final commandManager = _commandManager;
    if (commandManager == null) {
      if (showFeedback && context != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun classeur à enregistrer.')),
        );
      }
      return;
    }
    try {
      final runtime = _scriptRuntime;
      if (runtime != null) {
        await runtime.dispatchWorkbookBeforeSave();
      }
      await _workbookStorage.save(commandManager.workbook);
      if (showFeedback && context != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classeur enregistré avec succès.')),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Failed to save workbook: $error\n$stackTrace');
      if (showFeedback && context != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $error'),
          ),
        );
      }
    }
  }

  Workbook _createInitialWorkbook() {
    const rowCount = 20;
    const columnCount = 8;
    final rows = List<List<Cell>>.generate(
      rowCount,
      (row) => List<Cell>.generate(
        columnCount,
        (column) =>
            Cell(row: row, column: column, type: CellType.empty, value: null),
      ),
      growable: false,
    );
    final sheet = Sheet(name: 'Feuille 1', rows: rows);
    final menu = MenuPage(name: 'Menu principal');
    return Workbook(pages: [menu, sheet]);
  }

  @override
  Widget build(BuildContext context) {
    final commandManager = _commandManager;
    final runtime = _scriptRuntime;

    Widget home;
    if (_isLoading) {
      home = const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    } else if (_loadingError != null || commandManager == null || runtime == null) {
      home = Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text('Impossible de charger le classeur.'),
              if (_loadingError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _loadingError.toString(),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initialiseApp,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    } else {
      home = WorkbookHome(
        commandManager: commandManager,
        scriptRuntime: runtime,
        mode: _mode,
        onModeChanged: _updateMode,
        onSaveRequested: (context) =>
            _queueSave(showFeedback: true, context: context),
      );
    }

    return MaterialApp(
      title: 'Classeur Optima',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: home,
    );
  }
}

class WorkbookHome extends StatelessWidget {
  const WorkbookHome({
    super.key,
    required this.commandManager,
    required this.scriptRuntime,
    required this.mode,
    required this.onModeChanged,
    required this.onSaveRequested,
  });

  final WorkbookCommandManager commandManager;
  final ScriptRuntime scriptRuntime;
  final AppMode mode;
  final ValueChanged<AppMode> onModeChanged;
  final Future<void> Function(BuildContext context) onSaveRequested;

  @override
  Widget build(BuildContext context) {
    final isAdmin = mode == AppMode.admin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Classeur Optima'),
        actions: [
          IconButton(
            tooltip: 'Enregistrer le classeur',
            icon: const Icon(Icons.save_outlined),
            onPressed: () => onSaveRequested(context),
          ),
          _ModeSwitcher(mode: mode, onChanged: onModeChanged),
          const SizedBox(width: 12),
          _ProfileBadge(isAdmin: isAdmin),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 1200 ? 32.0 : 16.0;
            final verticalPadding = constraints.maxHeight > 720 ? 16.0 : 8.0;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: verticalPadding,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.18),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: WorkbookNavigator(
                        commandManager: commandManager,
                        scriptRuntime: scriptRuntime,
                        isAdmin: isAdmin,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ModeSwitcher extends StatelessWidget {
  const _ModeSwitcher({required this.mode, required this.onChanged});

  final AppMode mode;
  final ValueChanged<AppMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppMode>(
      tooltip: 'Changer de mode',
      initialValue: mode,
      icon: Icon(mode.icon),
      onSelected: onChanged,
      itemBuilder: (context) => AppMode.values
          .map(
            (appMode) => PopupMenuItem<AppMode>(
              value: appMode,
              child: Row(
                children: [
                  Icon(appMode.icon, size: 18),
                  const SizedBox(width: 12),
                  Text(appMode.label),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ProfileBadge extends StatelessWidget {
  const _ProfileBadge({this.isAdmin = false});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = colorScheme.surface;
    final borderColor = colorScheme.outline.withOpacity(0.2);
    final icon = isAdmin ? Icons.admin_panel_settings : Icons.person_outline;
    final label = isAdmin ? 'Administrateur' : 'Utilisateur';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: background,
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              child: Icon(icon, size: 16, color: colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
