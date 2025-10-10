import 'package:optimascript/api.dart';

Future<void> onPageEnter(ScriptContext context) async {
  final sheet = context.api.workbook.activeSheet;
  sheet?.cellByLabel('A1')?.setValue('Feuille 1 ouverte');
  await context.callHost(
    'log',
    positional: <Object?>['Entrée sur la page feuille_1 avec l\'API Dart Test XXX 3.'],
  );
}

Future<void> onPageLeave(ScriptContext context) async {
  await context.callHost(
    'log',
    positional: <Object?>['Sortie de la page feuille_1 avec l\'API Dart.'],
  );
}
