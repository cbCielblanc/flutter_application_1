import 'package:optimascript/api.dart';

Future<void> onInvoke(ScriptContext context) async {
  await context.callHost(
    'log',
    positional: <Object?>['Utilitaire partagé exécuté via l\'API Dart.'],
  );
}
