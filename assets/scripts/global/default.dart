import 'package:optimascript/api.dart';

Future<void> onWorkbookOpen(ScriptContext context) async {
  await context.callHost(
    'log',
    positional: <Object?>['Classeur initialisé via OptimaScript Dart.'],
  );
}

Future<void> onWorkbookClose(ScriptContext context) async {
  await context.callHost(
    'log',
    positional: <Object?>['Classeur fermé via OptimaScript Dart.'],
  );
}
