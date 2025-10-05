import 'package:optimascript/api.dart';

Future<void> onPageEnter(ScriptContext context) async {
  await context.callHost(
    'log',
    positional: <Object?>['Ouverture du menu principal via l\'API Dart.'],
  );
}

Future<void> onPageLeave(ScriptContext context) async {
  await context.callHost(
    'log',
    positional: <Object?>['Fermeture du menu principal via l\'API Dart.'],
  );
}
