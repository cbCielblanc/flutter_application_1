import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/application/commands/set_cell_value_command.dart';
import 'package:flutter_application_1/application/commands/workbook_command_manager.dart';
import 'package:flutter_application_1/application/scripts/runtime.dart';
import 'package:flutter_application_1/application/scripts/storage.dart';
import 'package:flutter_application_1/domain/menu_page.dart';
import 'package:flutter_application_1/domain/sheet.dart';
import 'package:flutter_application_1/domain/workbook.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/services/workbook_storage.dart';

void main() {
  testWidgets('tab changes do not trigger saves while cell edits do',
      (tester) async {
    final workbook = Workbook(
      pages: [
        MenuPage(name: 'Menu'),
        Sheet.fromRows(name: 'Feuille 1', rows: const <List<Object?>>[
          <Object?>[null],
        ]),
      ],
    );
    final storage = _TestWorkbookStorage(initialWorkbook: workbook);

    await tester.pumpWidget(MyApp(
      workbookStorageBuilder: () => storage,
      scriptStorageBuilder: ScriptStorage.new,
      scriptRuntimeBuilder: (scriptStorage, commandManager) =>
          _TestScriptRuntime(storage: scriptStorage, commandManager: commandManager),
    ));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpAndSettle();

    final state = tester.state<State<MyApp>>(find.byType(MyApp));
    final commandManager =
        (state as dynamic).commandManagerForTesting as WorkbookCommandManager?;
    expect(commandManager, isNotNull);

    expect(storage.saveCallCount, 0);

    commandManager!.setActivePage(1);
    await tester.pump();
    expect(storage.saveCallCount, 0, reason: 'Tab change should not trigger save');

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

    expect(storage.saveCallCount, 1,
        reason: 'Cell edit should trigger a workbook save');
  });
}

class _TestWorkbookStorage extends WorkbookStorage {
  _TestWorkbookStorage({required Workbook initialWorkbook})
      : _initialWorkbook = initialWorkbook,
        super(appSupportDirectoryProvider: () async => Directory.systemTemp);

  final Workbook _initialWorkbook;
  int saveCallCount = 0;

  @override
  Future<Workbook?> load() async => _initialWorkbook;

  @override
  Future<void> save(Workbook workbook) async {
    saveCallCount++;
  }
}

class _TestScriptRuntime extends ScriptRuntime {
  _TestScriptRuntime({
    required super.storage,
    required super.commandManager,
  });

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispatchWorkbookOpen() async {}

  @override
  Future<void> dispatchWorkbookClose() async {}

  @override
  Future<void> dispatchWorkbookBeforeSave({
    bool saveAs = false,
    bool isAutoSave = false,
  }) async {}
}
