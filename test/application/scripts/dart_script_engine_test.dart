import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/application/commands/workbook_command_manager.dart';
import 'package:flutter_application_1/application/scripts/context.dart';
import 'package:flutter_application_1/application/scripts/dart/dart_script_engine.dart';
import 'package:flutter_application_1/application/scripts/models.dart';
import 'package:flutter_application_1/domain/sheet.dart';
import 'package:flutter_application_1/domain/workbook.dart';

void main() {
  group('DartScriptEngine', () {
    test('loads a module and invokes a callback', () async {
      final calls = <String>[];
      final host = DartBindingHost(
        functions: <String, DartHostFunction>{
          'capture': (context, positional, {named}) async {
            final message =
                positional.isEmpty ? '' : positional.first?.toString() ?? '';
            calls.add('${context.eventType.wireName}:$message');
            await context.logMessage('ctx:$message');
          },
        },
      );

      const source = '''
{
  "onWorkbookOpen": [
    {"call": "capture", "args": ["bonjour"]},
    {"call": "capture", "args": ["monde"]}
  ]
}
''';

      const descriptor = ScriptDescriptor(
        scope: ScriptScope.global,
        key: 'test_module',
      );

      final engine = DartScriptEngine(bindingHost: host);
      final module = await engine.loadModule(
        descriptor: descriptor,
        source: source,
      );

      expect(module.exportNames, contains('onWorkbookOpen'));
      final export = module['onWorkbookOpen'];
      expect(export, isNotNull);

      final workbook = Workbook(
        pages: [
          Sheet.fromRows(name: 'Feuille 1', rows: const [<Object?>[null]]),
        ],
      );
      final manager = WorkbookCommandManager(initialWorkbook: workbook);

      final context = ScriptContext(
        descriptor: descriptor,
        eventType: ScriptEventType.workbookOpen,
        workbook: workbook,
        commandManager: manager,
        log: (message) => calls.add('log:$message'),
      );

      await export!.call(context);

      expect(
        calls,
        <String>[
          'workbook.open:bonjour',
          'log:ctx:bonjour',
          'workbook.open:monde',
          'log:ctx:monde',
        ],
      );
    });

    test('throws when using an unknown host function', () async {
      const descriptor = ScriptDescriptor(
        scope: ScriptScope.global,
        key: 'invalid',
      );
      const source = '{"onWorkbookOpen": {"call": "unknown"}}';
      final engine = DartScriptEngine();

      expect(
        () => engine.loadModule(descriptor: descriptor, source: source),
        throwsA(isA<DartScriptCompilationException>()),
      );
    });
  });
}
