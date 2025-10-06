import 'package:highlight/highlight.dart';
import 'package:highlight/languages/dart.dart' as highlight_dart;

const List<String> _scriptCallbacks = [
  'onWorkbookOpen',
  'onWorkbookBeforeSave',
  'onWorksheetActivate',
  'onWorksheetDeactivate',
  'onWorksheetBeforeSingleClick',
  'onWorksheetBeforeDoubleClick',
  'onPageEnter',
  'onCellChanged',
];

const List<String> _scriptContextTypes = [
  'ScriptContext',
  'RangeApi',
  'RowApi',
  'ColumnApi',
  'ChartApi',
];

/// Builds the OptimaScript highlighting mode by extending the base Dart mode
/// with additional callbacks and API types from the OptimaScript runtime.
Mode buildScriptLanguage() {
  final Mode base = Mode.inherit(highlight_dart.dart, Mode())
    ..refs = highlight_dart.dart.refs;

  final dynamic baseKeywords = highlight_dart.dart.keywords;
  if (baseKeywords is Map<String, dynamic>) {
    final Map<String, dynamic> mergedKeywords =
        Map<String, dynamic>.from(baseKeywords);
    final String updatedBuiltIns = _mergeBuiltIns(baseKeywords['built_in']);
    mergedKeywords['built_in'] = updatedBuiltIns;
    base.keywords = mergedKeywords;
  } else if (baseKeywords is String) {
    base.keywords = {
      'keyword': baseKeywords,
      'built_in': _mergeBuiltIns(null),
    };
  } else {
    base.keywords = {
      'built_in': _mergeBuiltIns(null),
    };
  }

  return base;
}

String _mergeBuiltIns(dynamic existingBuiltIns) {
  final Set<String> builtIns = <String>{};
  if (existingBuiltIns is String && existingBuiltIns.isNotEmpty) {
    builtIns.addAll(existingBuiltIns
        .split(RegExp(r'\s+'))
        .where((String token) => token.isNotEmpty));
  } else if (existingBuiltIns is Iterable) {
    builtIns.addAll(existingBuiltIns
        .whereType<String>()
        .where((String token) => token.isNotEmpty));
  }
  builtIns.addAll(_scriptCallbacks);
  builtIns.addAll(_scriptContextTypes);
  return builtIns.join(' ');
}

/// Syntax highlighting mode for OptimaScript Dart scripts.
final Mode scriptLanguage = buildScriptLanguage();
