import 'package:optimascript/api.dart';

Future<void> onPageEnter(ScriptContext context) async {
  await context.callHost(
    'log',
    positional: <Object?>['Ouverture des notes_1 via l\'API Dart.'],
  );
}

Future<void> onNotesChanged(ScriptContext context) async {
  await context.callHost(
    'log',
    positional: <Object?>['Contenu des notes_1 mis à jour.'],
  );
}

Future<void> onPageLeave(ScriptContext context) async {
  await context.callHost(
    'log',
    positional: <Object?>['Fermeture des notes_1 via l\'API Dart.'],
  );
}
