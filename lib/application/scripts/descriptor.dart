import 'scope.dart';

class ScriptDescriptor {
  const ScriptDescriptor({required this.scope, required this.key});

  final ScriptScope scope;
  final String key;

  String get fileName {
    switch (scope) {
      case ScriptScope.global:
        return 'global/$key.json';
      case ScriptScope.page:
        return 'pages/$key.json';
      case ScriptScope.shared:
        return 'shared/$key.json';
    }
  }
}

String normaliseScriptKey(String input) {
  final buffer = StringBuffer();
  final lowered = input.trim().toLowerCase();
  var previousWasSeparator = true;
  for (final rune in lowered.runes) {
    final char = String.fromCharCode(rune);
    final isAllowed = RegExp(r'[a-z0-9]').hasMatch(char);
    if (isAllowed) {
      buffer.write(char);
      previousWasSeparator = false;
    } else if (!previousWasSeparator) {
      buffer.write('_');
      previousWasSeparator = true;
    }
  }
  var result = buffer.toString();
  result = result.replaceAll(RegExp(r'_+'), '_');
  result = result.replaceAll(RegExp(r'^_|_$'), '');
  if (result.isEmpty) {
    return 'script';
  }
  return result;
}
