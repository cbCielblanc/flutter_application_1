import 'package:flutter/material.dart';

import '../../application/commands/add_sheet_command.dart';
import '../../application/commands/clear_sheet_command.dart';
import '../../application/commands/insert_column_command.dart';
import '../../application/commands/insert_row_command.dart';
import '../../application/commands/populate_sample_data_command.dart';
import '../../application/commands/remove_sheet_command.dart';
import '../../application/commands/uppercase_header_command.dart';
import '../../application/commands/workbook_command.dart';
import '../../application/commands/workbook_command_manager.dart';

typedef WorkbookCommandBuilder = WorkbookCommand Function();

class CommandRibbon extends StatelessWidget {
  const CommandRibbon({super.key, required this.commandManager});

  final WorkbookCommandManager commandManager;

  static final List<WorkbookCommandBuilder> _editionCommands =
      <WorkbookCommandBuilder>[
    () => AddSheetCommand(),
    () => InsertRowCommand(),
    () => InsertColumnCommand(),
    () => RemoveSheetCommand(),
  ];

  static final List<WorkbookCommandBuilder> _formatCommands =
      <WorkbookCommandBuilder>[
    () => UppercaseHeaderCommand(),
  ];

  static final List<WorkbookCommandBuilder> _dataCommands =
      <WorkbookCommandBuilder>[
    () => PopulateSampleDataCommand(),
    () => ClearSheetCommand(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: commandManager,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Material(
            elevation: 2,
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 32,
                runSpacing: 16,
                children: [
                  _HistoryGroup(manager: commandManager),
                  _CommandGroup(
                    title: 'Édition',
                    commands: _editionCommands,
                    manager: commandManager,
                  ),
                  _CommandGroup(
                    title: 'Format',
                    commands: _formatCommands,
                    manager: commandManager,
                  ),
                  _CommandGroup(
                    title: 'Données',
                    commands: _dataCommands,
                    manager: commandManager,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CommandGroup extends StatelessWidget {
  const _CommandGroup({
    required this.title,
    required this.commands,
    required this.manager,
  });

  final String title;
  final List<WorkbookCommandBuilder> commands;
  final WorkbookCommandManager manager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final builder in commands)
                _CommandButton(builder: builder, manager: manager),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({required this.builder, required this.manager});

  final WorkbookCommandBuilder builder;
  final WorkbookCommandManager manager;

  @override
  Widget build(BuildContext context) {
    final prototype = builder();
    final canExecute = prototype.canExecute(manager.context);
    return SizedBox(
      width: 180,
      child: FilledButton.tonal(
        onPressed: canExecute ? () => manager.execute(builder()) : null,
        child: Text(
          prototype.label,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _HistoryGroup extends StatelessWidget {
  const _HistoryGroup({required this.manager});

  final WorkbookCommandManager manager;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Historique',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HistoryButton(
                label: 'Annuler',
                isEnabled: manager.canUndo,
                onPressed: manager.undo,
              ),
              _HistoryButton(
                label: 'Rétablir',
                isEnabled: manager.canRedo,
                onPressed: manager.redo,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryButton extends StatelessWidget {
  const _HistoryButton({
    required this.label,
    required this.isEnabled,
    required this.onPressed,
  });

  final String label;
  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: FilledButton.tonal(
        onPressed: isEnabled ? onPressed : null,
        child: Text(
          label,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
