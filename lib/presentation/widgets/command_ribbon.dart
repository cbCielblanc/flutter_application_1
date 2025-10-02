import 'package:flutter/material.dart';

import '../../application/commands/clear_sheet_command.dart';
import '../../application/commands/insert_column_command.dart';
import '../../application/commands/insert_row_command.dart';
import '../../application/commands/populate_sample_data_command.dart';
import '../../application/commands/uppercase_header_command.dart';
import '../../application/commands/workbook_command.dart';
import '../../application/commands/workbook_command_manager.dart';
import '../../domain/workbook.dart';

typedef WorkbookCommandBuilder = WorkbookCommand Function();

class CommandRibbon extends StatelessWidget {
  const CommandRibbon({
    super.key,
    required this.commandManager,
    this.onBeforeCommand,
  });

  final WorkbookCommandManager commandManager;
  final VoidCallback? onBeforeCommand;

  static final List<_CommandMenuConfig> _menus = <_CommandMenuConfig>[
    _CommandMenuConfig(
      label: 'Structure',
      icon: Icons.table_chart_outlined,
      builders: <WorkbookCommandBuilder>[
        () => InsertRowCommand(),
        () => InsertColumnCommand(),
      ],
    ),
    _CommandMenuConfig(
      label: 'Donnees',
      icon: Icons.dataset_outlined,
      builders: <WorkbookCommandBuilder>[
        () => PopulateSampleDataCommand(),
        () => ClearSheetCommand(),
      ],
    ),
    _CommandMenuConfig(
      label: 'Format',
      icon: Icons.text_fields,
      builders: <WorkbookCommandBuilder>[
        () => UppercaseHeaderCommand(),
      ],
    ),
  ];

  Workbook get _workbook => commandManager.workbook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AnimatedBuilder(
      animation: commandManager,
      builder: (context, _) {
        final currentPageName = _activePageName(_workbook, commandManager.activePageIndex);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Material(
            color: colorScheme.surface,
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.06),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _ToolbarIconButton(
                      icon: Icons.undo,
                      tooltip: 'Annuler',
                      onPressed: commandManager.canUndo
                          ? () {
                              onBeforeCommand?.call();
                              commandManager.undo();
                            }
                          : null,
                    ),
                    _ToolbarIconButton(
                      icon: Icons.redo,
                      tooltip: 'Retablir',
                      onPressed: commandManager.canRedo
                          ? () {
                              onBeforeCommand?.call();
                              commandManager.redo();
                            }
                          : null,
                    ),
                    const VerticalDivider(width: 24, thickness: 1),
                    for (final menu in _menus) ...[
                      _CommandMenu(
                        config: menu,
                        manager: commandManager,
                        onBeforeCommand: onBeforeCommand,
                      ),
                      const SizedBox(width: 6),
                    ],
                    const Spacer(),
                    _ActivePageBadge(name: currentPageName),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _activePageName(Workbook workbook, int activeIndex) {
    if (activeIndex < 0 || activeIndex >= workbook.pages.length) {
      return 'Aucune page active';
    }
    return workbook.pages[activeIndex].name;
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        visualDensity: VisualDensity.compact,
        splashRadius: 20,
      ),
    );
  }
}

class _CommandMenu extends StatelessWidget {
  const _CommandMenu({
    required this.config,
    required this.manager,
    this.onBeforeCommand,
  });

  final _CommandMenuConfig config;
  final WorkbookCommandManager manager;
  final VoidCallback? onBeforeCommand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final enabled = config.builders.any((builder) {
      final prototype = builder();
      return prototype.canExecute(manager.context);
    });

    final menuButton = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: enabled ? colorScheme.surfaceContainerHighest.withOpacity(0.4) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: 20,
            color: enabled ? colorScheme.primary : theme.disabledColor,
          ),
          const SizedBox(width: 8),
          Text(
            config.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: enabled ? theme.textTheme.bodyMedium?.color : theme.disabledColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: enabled ? colorScheme.primary : theme.disabledColor,
          ),
        ],
      ),
    );

    if (!enabled) {
      return Opacity(opacity: 0.6, child: menuButton);
    }

    return PopupMenuButton<WorkbookCommandBuilder>(
      tooltip: config.label,
      itemBuilder: (context) {
        return [
          for (final builder in config.builders)
            _buildMenuItem(context: context, builder: builder),
        ].whereType<PopupMenuEntry<WorkbookCommandBuilder>>().toList();
      },
      onSelected: (builder) {
        onBeforeCommand?.call();
        manager.execute(builder());
      },
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      child: menuButton,
    );
  }

  PopupMenuEntry<WorkbookCommandBuilder> _buildMenuItem({
    required BuildContext context,
    required WorkbookCommandBuilder builder,
  }) {
    final prototype = builder();
    final canExecute = prototype.canExecute(manager.context);
    final icon = _iconForCommand(prototype);
    final theme = Theme.of(context);
    return PopupMenuItem<WorkbookCommandBuilder>(
      enabled: canExecute,
      value: builder,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: canExecute ? theme.colorScheme.primary : theme.disabledColor,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              prototype.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivePageBadge extends StatelessWidget {
  const _ActivePageBadge({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.primary.withOpacity(0.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              name,
              style: theme.textTheme.labelLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommandMenuConfig {
  const _CommandMenuConfig({
    required this.label,
    required this.icon,
    required this.builders,
  });

  final String label;
  final IconData icon;
  final List<WorkbookCommandBuilder> builders;
}

IconData _iconForCommand(WorkbookCommand command) {
  if (command is InsertRowCommand) {
    return Icons.table_rows_outlined;
  }
  if (command is InsertColumnCommand) {
    return Icons.view_week_outlined;
  }
  if (command is PopulateSampleDataCommand) {
    return Icons.auto_awesome;
  }
  if (command is ClearSheetCommand) {
    return Icons.cleaning_services_outlined;
  }
  if (command is UppercaseHeaderCommand) {
    return Icons.text_fields;
  }
  return Icons.tune;
}
