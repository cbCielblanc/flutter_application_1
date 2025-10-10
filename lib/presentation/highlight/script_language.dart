import 'package:highlight/highlight.dart';
import 'package:highlight/languages/dart.dart' as highlight_dart;

const List<String> _scriptCallbacks = [
  'onWorkbookOpen',
  'onWorkbookClose',
  'onWorkbookBeforeSave',
  'onWorksheetActivate',
  'onWorksheetDeactivate',
  'onWorksheetBeforeSingleClick',
  'onWorksheetBeforeDoubleClick',
  'onSelectionChanged',
  'onNotesChanged',
  'onPageEnter',
  'onPageLeave',
  'onInvoke',
  'onCellChanged',
];

const List<String> _scriptContextTypes = [
  'ScriptContext',
  'ScriptDescriptor',
  'ScriptRuntime',
  'ScriptScope',
  'ScriptApi',
  'WorkbookApi',
  'SheetApi',
  'CellApi',
  'RangeApi',
  'RowApi',
  'ColumnApi',
  'ChartApi',
  'CustomAction',
];

const List<String> _dartCoreAugmentations = [
  'Future',
  'FutureOr',
  'Stream',
  'StreamSubscription',
  'StreamController',
  'Timer',
  'Iterable',
  'Iterator',
  'List',
  'Map',
  'Set',
  'Record',
  'Symbol',
  'Pattern',
  'String',
  'DateTime',
  'Duration',
  'RegExp',
  'Uri',
  'Exception',
  'State',
  'Widget',
  'StatelessWidget',
  'StatefulWidget',
  'BuildContext',
  'Color',
  'Offset',
  'Size',
  'Rect',
  'ThemeData',
  'TextStyle',
  'TextSpan',
];

bool _initialised = false;

/// Returns the customised Dart highlighting mode with OptimaScript additions.
Mode buildScriptLanguage() {
  if (_initialised) {
    return highlight_dart.dart;
  }

  final Mode base = highlight_dart.dart;
  final dynamic keywords = base.keywords;

  if (keywords is Map) {
    final dynamic existingBuiltIns = keywords['built_in'];
    keywords['built_in'] = _mergeBuiltIns(existingBuiltIns);
  } else if (keywords is String) {
    base.keywords = {
      'keyword': keywords,
      'built_in': _mergeBuiltIns(null),
    };
  } else {
    base.keywords = {
      'built_in': _mergeBuiltIns(null),
    };
  }

  _initialised = true;
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
  builtIns.addAll(_dartCoreAugmentations);
  return builtIns.join(' ');
}

/// Syntax highlighting mode for OptimaScript Dart scripts.
final Mode scriptLanguage = buildScriptLanguage();
