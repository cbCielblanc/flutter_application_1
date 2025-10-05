import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/application/commands/workbook_command_manager.dart';
import 'package:flutter_application_1/application/scripts/dart/dart_script_engine.dart';
import 'package:flutter_application_1/application/scripts/models.dart';
import 'package:flutter_application_1/application/scripts/runtime.dart';
import 'package:flutter_application_1/application/scripts/storage.dart';
import 'package:flutter_application_1/domain/sheet.dart';
import 'package:flutter_application_1/domain/workbook.dart';
import 'package:flutter_application_1/presentation/workbook_navigator/workbook_navigator.dart';

class _CapturingScriptStorage extends ScriptStorage {
  _CapturingScriptStorage()
      : super(
          bundle: _FakeAssetBundle(),
        );

  final List<StoredScript> savedScripts = <StoredScript>[];

  @override
  Future<void> initialize({bool precompileAssets = false}) async {}

  @override
  List<String> get migrationWarnings => const <String>[];

  @override
  Future<StoredScript?> loadScript(ScriptDescriptor descriptor) async {
    return null;
  }

  @override
  Future<List<StoredScript>> loadAll({ScriptScope? scope}) async {
    if (scope == null) {
      return List<StoredScript>.from(savedScripts);
    }
    return savedScripts
        .where((script) => script.descriptor.scope == scope)
        .toList(growable: false);
  }

  @override
  Future<StoredScript> saveScript(
    ScriptDescriptor descriptor,
    String source, {
    ScriptDocument? validatedDocument,
  }) async {
    final module = DartScriptModule(
      descriptor: descriptor,
      source: source,
      libraryUri: 'memory://${descriptor.fileName}',
      runtime: null,
      exports: const <String, DartScriptExport>{},
      signatures: const <String, DartScriptSignature>{},
    );
    final document = ScriptDocument(
      id: descriptor.key,
      name: descriptor.key,
      scope: descriptor.scope,
      module: module,
      exports: const <String, DartScriptExport>{},
      signatures: const <String, DartScriptSignature>{},
    );
    final stored = StoredScript(
      descriptor: descriptor,
      source: source,
      document: document,
      origin: 'memory',
      isMutable: true,
    );
    savedScripts.removeWhere(
      (script) =>
          script.descriptor.scope == descriptor.scope &&
          script.descriptor.key == descriptor.key,
    );
    savedScripts.add(stored);
    return stored;
  }
}

class _FakeAssetBundle extends CachingAssetBundle {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creates OptimaScript template when opening editor for missing page script', (tester) async {
    final storage = _CapturingScriptStorage();
    final workbook = Workbook(
      pages: <Sheet>[
        Sheet.fromRows(
          name: 'Feuille 1',
          rows: const <List<Object?>>[<Object?>[null]],
        ),
      ],
    );
    final manager = WorkbookCommandManager(initialWorkbook: workbook);
    final runtime = ScriptRuntime(
      storage: storage,
      commandManager: manager,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkbookNavigator(
            commandManager: manager,
            scriptRuntime: runtime,
            isAdmin: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(storage.savedScripts, isNotEmpty);
    final saved = storage.savedScripts.first;
    expect(saved.descriptor.scope, ScriptScope.page);
    expect(saved.source, contains('ScriptContext context'));
    expect(saved.source, contains('context.api.workbook'));
    expect(saved.source, contains("context.callHost('log'"));

    final engine = DartScriptEngine();
    final module = await engine.validate(
      descriptor: saved.descriptor,
      source: saved.source,
    );
    expect(module.exportNames, contains('onPageEnter'));
    expect(module.exportNames, contains('onPageLeave'));
  });
}
