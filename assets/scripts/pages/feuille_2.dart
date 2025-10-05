import 'package:optimascript/api.dart';

Future<void> onPageEnter(ScriptContext context) async {
  await context.callHost(
    'log',
    positional: <Object?>['Entrée sur la page feuille_2 avec l\'API Dart.'],
  );
}

Future<void> onPageLeave(ScriptContext context) async {
  await context.callHost(
    'log',
    positional: <Object?>['Sortie de la page feuille_2 avec l\'API Dart.'],
  );
}
