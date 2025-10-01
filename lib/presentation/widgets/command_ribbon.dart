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

class CommandRibbon extends StatelessWidget {
  const CommandRibbon({super.key, required this.commandManager});

  final WorkbookCommandManager commandManager;

  static const List<WorkbookCommand> _editionCommands = <WorkbookCommand>[
    AddSheetCommand(),
    InsertRowCommand(),
    InsertColumnCommand(),
    RemoveSheetCommand(),
  ];

  static const List<WorkbookCommand> _formatCommands = <WorkbookCommand>[
    UppercaseHeaderCommand(),
  ];

  static const List<WorkbookCommand> _dataCommands = <WorkbookCommand>[
    PopulateSampleDataCommand(),
    ClearSheetCommand(),
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
  final List<WorkbookCommand> commands;
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
              for (final command in commands)
                _CommandButton(command: command, manager: manager),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({required this.command, required this.manager});

  final WorkbookCommand command;
  final WorkbookCommandManager manager;

  @override
  Widget build(BuildContext context) {
    final canExecute = command.canExecute(manager.context);
    return SizedBox(
      width: 180,
      child: FilledButton.tonal(
        onPressed: canExecute ? () => manager.execute(command) : null,
        child: Text(
          command.label,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
