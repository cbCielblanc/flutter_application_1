import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/application/commands/set_cell_value_command.dart';
import 'package:flutter_application_1/application/commands/workbook_command_manager.dart';
import 'package:flutter_application_1/application/scripts/runtime.dart';
import 'package:flutter_application_1/application/scripts/storage.dart';
import 'package:flutter_application_1/domain/menu_page.dart';
import 'package:flutter_application_1/domain/sheet.dart';
import 'package:flutter_application_1/domain/workbook.dart';
import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('save button triggers script hook and shows disabled message',
      (tester) async {
    final workbook = Workbook(
      pages: [
        MenuPage(name: 'Menu'),
        Sheet.fromRows(name: 'Feuille 1', rows: const <List<Object?>>[
          <Object?>[null],
        ]),
      ],
    );
    late _TestScriptRuntime runtime;

    await tester.pumpWidget(MyApp(
      workbookFactory: () => workbook,
      scriptStorageBuilder: ScriptStorage.new,
      scriptRuntimeBuilder: (scriptStorage, commandManager) {
        runtime = _TestScriptRuntime(
          storage: scriptStorage,
          commandManager: commandManager,
        );
        return runtime;
      },
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();

    final state = tester.state<State<MyApp>>(find.byType(MyApp));
    final commandManager =
        (state as dynamic).commandManagerForTesting as WorkbookCommandManager?;
    expect(commandManager, isNotNull);

    expect(runtime.initializeCallCount, 1);
    expect(runtime.openCallCount, 1);
    expect(runtime.beforeSaveCallCount, 0);

    commandManager!.setActivePage(1);
    await tester.pump();
    expect(runtime.beforeSaveCallCount, 0,
        reason: 'Tab change should not trigger script save hook');

    final sheetName = commandManager.workbook.sheets.first.name;
    final changed = commandManager.execute(SetCellValueCommand(
      sheetName: sheetName,
      row: 0,
      column: 0,
      value: 'updated',
    ));
    expect(changed, isTrue);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();

    expect(runtime.beforeSaveCallCount, 0,
        reason: 'Cell edit should not trigger script save hook automatically');

    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();

    expect(runtime.beforeSaveCallCount, 1,
        reason: 'Manual save should trigger script hook');
    expect(find.text('La sauvegarde des feuilles est désactivée.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(runtime.closeCallCount, 1);
  });
}

class _TestScriptRuntime extends ScriptRuntime {
  _TestScriptRuntime({
    required super.storage,
    required super.commandManager,
  });

  int initializeCallCount = 0;
  int openCallCount = 0;
  int closeCallCount = 0;
  int beforeSaveCallCount = 0;

  @override
  Future<void> initialize() async {
    initializeCallCount++;
  }

  @override
  Future<void> dispatchWorkbookOpen() async {
    openCallCount++;
  }

  @override
  Future<void> dispatchWorkbookClose() async {
    closeCallCount++;
  }

  @override
  Future<void> dispatchWorkbookBeforeSave({
    bool saveAs = false,
    bool isAutoSave = false,
  }) async {
    beforeSaveCallCount++;
  }
}
