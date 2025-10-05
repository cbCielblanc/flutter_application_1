import 'package:optimascript/api.dart';

Future<void> onWorkbookOpen(ScriptContext context) async {
  final workbook = context.api.workbook;
  final activeSheet = workbook.activeSheet;
  if (activeSheet != null) {
    final cell = activeSheet.cellAt(0, 0);
    if (cell.isEmpty) {
      cell.setValue('Bienvenue via ScriptApi');
    }
  }
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
