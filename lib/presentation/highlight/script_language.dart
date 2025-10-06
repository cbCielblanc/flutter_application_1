import 'package:highlight/highlight.dart';
import 'package:highlight/languages/dart.dart' as highlight_dart;

const List<String> _scriptCallbacks = [
  'onWorkbookOpen',
  'onWorkbookClose',
  'onWorkbookBeforeSave',
  'onPageEnter',
  'onPageLeave',
  'onWorksheetActivate',
  'onWorksheetDeactivate',
  'onCellChanged',
  'onSelectionChanged',
  'onNotesChanged',
  'onWorksheetBeforeSingleClick',
  'onWorksheetBeforeDoubleClick',
  'onInvoke',
];

const List<String> _scriptContextTypes = [
  'ScriptContext',
  'ScriptApi',
  'WorkbookApi',
  'SheetApi',
  'CellApi',
  'RangeApi',
  'RowApi',
  'ColumnApi',
  'ChartApi',
];

const List<String> _dartCoreTypes = [
  'DateTime',
  'Duration',
  'Future',
  'FutureOr',
  'Stream',
  'StreamSubscription',
  'StreamController',
  'Iterable',
  'Iterator',
  'List',
  'Map',
  'Match',
  'Object',
  'Pattern',
  'RegExp',
  'Set',
  'Stopwatch',
  'String',
  'StringBuffer',
  'StringSink',
  'Symbol',
  'Type',
  'Uri',
];

const List<String> _scriptApiProperties = [
  'api',
  'logMessage',
  'callHost',
  'workbook',
  'sheetNames',
  'activeSheetIndex',
  'activeSheet',
  'sheetByName',
  'sheetAt',
  'activateSheetByName',
  'activateSheetAt',
  'name',
  'rowCount',
  'columnCount',
  'activate',
  'cellAt',
  'cellByLabel',
  'insertRow',
  'insertColumn',
  'clear',
  'range',
  'row',
  'column',
  'chart',
  'sheetName',
  'label',
  'value',
  'text',
  'isEmpty',
  'type',
  'lastResult',
  'values',
  'setValue',
  'setValues',
  'fillDown',
  'fillRight',
  'sortByColumn',
  'formatAsNumber',
  'autoFit',
  'index',
  'asRange',
  'updateRange',
  'describe',
];

const Set<String> _primitiveTypeTokens = {
  'bool',
  'double',
  'dynamic',
  'int',
  'Never',
  'Null',
  'num',
};

/// Builds the OptimaScript highlighting mode by extending the base Dart mode
/// with OptimaScript-specific callbacks, API surface and a richer token
/// classification to approach the Visual Studio Code Dart experience.
Mode buildScriptLanguage() {
  final Mode base = Mode.inherit(highlight_dart.dart, Mode())
    ..refs = highlight_dart.dart.refs == null
        ? null
        : Map<String, Mode>.from(highlight_dart.dart.refs!);

  base.contains = base.contains == null
      ? <Mode?>[]
      : List<Mode?>.from(base.contains!);

  final Map<String, dynamic> keywordMap = _normalizeKeywordMap(base.keywords);

  final Set<String> keywords = _tokenize(keywordMap['keyword']);
  final Set<String> literals = _tokenize(keywordMap['literal']);
  final Set<String> builtIns = _tokenize(keywordMap['built_in']);

  final Set<String> typeTokens = <String>{
    ..._primitiveTypeTokens,
    ..._dartCoreTypes,
    ..._scriptContextTypes,
    ...builtIns.where(_looksLikeTypeToken),
  }..removeWhere((token) => token.isEmpty);

  final Set<String> builtInFunctions = <String>{
    ...builtIns.where((token) => !_looksLikeTypeToken(token)),
    ..._scriptCallbacks,
  }..removeWhere((token) => token.isEmpty);

  keywordMap
    ..['keyword'] = _joinTokens(keywords)
    ..['literal'] = _joinTokens(literals)
    ..['built_in'] = _joinTokens(builtInFunctions)
    ..['type'] = _joinTokens(typeTokens);

  base.keywords = keywordMap;

  final String callbackPattern =
      '\\b(?:${_scriptCallbacks.join('|')})\\b(?=\\s*\\()';
  final String propertyPattern =
      '\\.(?:${_scriptApiProperties.join('|')})\\b';

  base.contains!.addAll(<Mode>[
    Mode(
      className: 'title.function',
      begin: callbackPattern,
      relevance: 1,
    ),
    Mode(
      className: 'property',
      begin: propertyPattern,
      excludeBegin: true,
      relevance: 0,
    ),
  ]);

  return base;
}

Map<String, dynamic> _normalizeKeywordMap(dynamic keywords) {
  if (keywords is Map<String, dynamic>) {
    return Map<String, dynamic>.from(keywords);
  }
  if (keywords is String) {
    return <String, dynamic>{'keyword': keywords};
  }
  return <String, dynamic>{};
}

Set<String> _tokenize(dynamic value) {
  if (value == null) {
    return <String>{};
  }
  if (value is String) {
    return value
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toSet();
  }
  if (value is Iterable) {
    return value
        .whereType<String>()
        .expand((token) => token.split(RegExp(r'\s+')))
        .where((token) => token.isNotEmpty)
        .toSet();
  }
  return <String>{};
}

bool _looksLikeTypeToken(String token) {
  if (token.isEmpty) {
    return false;
  }
  if (_primitiveTypeTokens.contains(token)) {
    return true;
  }
  if (token.endsWith('Api')) {
    return true;
  }
  final String first = token[0];
  final bool isLetter = first.toLowerCase() != first.toUpperCase();
  final bool startsWithUppercase = first == first.toUpperCase();
  return isLetter && startsWithUppercase;
}

String _joinTokens(Set<String> tokens) {
  if (tokens.isEmpty) {
    return '';
  }
  final List<String> sorted = tokens.toList()..sort();
  return sorted.join(' ');
}

/// Syntax highlighting mode for OptimaScript Dart scripts.
final Mode scriptLanguage = buildScriptLanguage();
