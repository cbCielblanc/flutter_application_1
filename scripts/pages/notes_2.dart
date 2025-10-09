import 'package:optimascript/api.dart';

Future<void> onPageEnter(ScriptContext context) async {
  final sheet = context.api.workbook.activeSheet;
  final cell = sheet?.cellByLabel('A1');
  final pageKey = context.descriptor.key;
  cell?.setValue('Bienvenue sur la page ' + pageKey + '.');
  await context.callHost(
    'log',
    positional: <Object?>[
      'Page ' + pageKey + ' initialisée via OptimaScript Dart.',
    ],
  );
}

Future<void> onPageLeave(ScriptContext context) async {
  final pageKey = context.descriptor.key;
  await context.callHost(
    'log',
    positional: <Object?>[
      'Page ' + pageKey + ' quittée via OptimaScript Dart.',
    ],
  );
}
