import 'dart:async';
import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';
import 'package:dart_eval/src/eval/compiler/errors.dart';
import 'package:dart_eval/src/eval/utils/wrap_helper.dart';

import '../api/api.dart';
import '../context.dart';
import '../descriptor.dart';

/// Signature for a function exposed by the host application to scripts.
typedef DartHostFunction = FutureOr<void> Function(
  ScriptContext context,
  List<Object?> positional, {
  Map<String, Object?>? named,
});

/// Registry exposing host functions to scripts.
class DartBindingHost {
  static const DartBindingHost empty = DartBindingHost._(<String, DartHostFunction>{});

  const DartBindingHost._(this._functions);

  factory DartBindingHost({
    Map<String, DartHostFunction> functions = const <String, DartHostFunction>{},
  }) {
    if (functions.isEmpty) {
      return empty;
    }
    return DartBindingHost._(Map.unmodifiable(functions));
  }

  final Map<String, DartHostFunction> _functions;

  Map<String, DartHostFunction> get functions => _functions;

  bool get isEmpty => _functions.isEmpty;

  DartHostFunction? resolve(String name) => _functions[name];

  DartBindingHost copyWith({Map<String, DartHostFunction>? functions}) {
    if (functions == null) {
      return this;
    }
    return DartBindingHost(functions: functions);
  }
}

/// Signature for a compiled script callback.
typedef DartScriptCallback = FutureOr<void> Function(ScriptContext context);

/// Representation of a callable export defined by a script.
class DartScriptExport {
  const DartScriptExport({
    required this.name,
    required DartScriptCallback callback,
  }) : _callback = callback;

  final String name;
  final DartScriptCallback _callback;

  DartScriptCallback get callback => _callback;

  Future<void> call(ScriptContext context) async {
    await Future.sync(() => _callback(context));
  }
}

class DartScriptSignature {
  const DartScriptSignature({
    this.isAsync = false,
  });

  final bool isAsync;
}

/// Container for the compiled representation of a script.
class DartScriptModule {
  DartScriptModule({
    required this.descriptor,
    required this.source,
    required this.libraryUri,
    required Runtime? runtime,
    required Map<String, DartScriptExport> exports,
    required Map<String, DartScriptSignature> signatures,
  })  : runtime = runtime,
        exports = Map.unmodifiable(exports),
        signatures = Map.unmodifiable(signatures);

  final ScriptDescriptor descriptor;
  final String source;
  final String libraryUri;
  final Runtime? runtime;
  final Map<String, DartScriptExport> exports;
  final Map<String, DartScriptSignature> signatures;

  Iterable<String> get exportNames => exports.keys;

  DartScriptExport? operator [](String name) => exports[name];

  DartScriptSignature? signatureFor(String name) => signatures[name];
}

/// Thrown when a script cannot be parsed or validated.
class DartScriptCompilationException implements Exception {
  DartScriptCompilationException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Interpreter for OptimaScript modules written in a declarative JSON DSL.
class DartScriptEngine {
  const DartScriptEngine({DartBindingHost? bindingHost})
      : _bindingHost = bindingHost ?? DartBindingHost.empty;

  final DartBindingHost _bindingHost;

  Future<DartScriptModule> validate({
    required ScriptDescriptor descriptor,
    required String source,
  }) {
    return loadModule(
      descriptor: descriptor,
      source: source,
    );
  }

  Future<DartScriptModule> loadModule({
    required ScriptDescriptor descriptor,
    required String source,
  }) async {
    final libraryUri = _libraryUri(descriptor);
    final compiler = Compiler();
    final plugin = _OptimaScriptPlugin(_bindingHost);
    compiler.addPlugin(plugin);
    compiler.entrypoints.add(libraryUri);
    compiler.addSource(DartSource(_apiLibraryUri, _apiStub));

    Program program;
    try {
      program = compiler.compile({
        _packageName: <String, String>{
          descriptor.fileName: source,
        },
      });
    } on CompileError catch (error) {
      throw DartScriptCompilationException(
        'Erreur de compilation pour ${descriptor.fileName}: ${error.message}',
        cause: error,
      );
    } catch (error) {
      throw DartScriptCompilationException(
        'Erreur inattendue lors de la compilation de ${descriptor.fileName}: $error',
        cause: error,
      );
    }

    final runtime = Runtime.ofProgram(program);
    runtime.addPlugin(plugin);
    runtime.addTypeAutowrapper(
      (value) => value is ScriptContext
          ? $ScriptContext.wrap(value, _bindingHost)
          : null,
    );
    runtime.addTypeAutowrapper(
      (value) => value is ScriptApi ? $ScriptApi.wrap(value) : null,
    );
    runtime.addTypeAutowrapper(
      (value) => value is WorkbookApi ? $WorkbookApi.wrap(value) : null,
    );
    runtime.addTypeAutowrapper(
      (value) => value is SheetApi ? $SheetApi.wrap(value) : null,
    );
    runtime.addTypeAutowrapper(
      (value) => value is CellApi ? $CellApi.wrap(value) : null,
    );

    final exports = <String, DartScriptExport>{};
    final signatures = <String, DartScriptSignature>{};
    final libraryIndex = program.bridgeLibraryMappings[libraryUri];
    final topLevel =
        libraryIndex == null ? null : program.topLevelDeclarations[libraryIndex];
    final available = topLevel?.keys.toSet() ?? <String>{};

    for (final callback in _supportedCallbacks) {
      if (!available.contains(callback)) {
        continue;
      }
      exports[callback] = DartScriptExport(
        name: callback,
        callback: _createCallback(runtime, libraryUri, callback),
      );
      signatures[callback] = const DartScriptSignature(isAsync: true);
    }

    return DartScriptModule(
      descriptor: descriptor,
      source: source,
      libraryUri: libraryUri,
      runtime: runtime,
      exports: exports,
      signatures: signatures,
    );
  }

  DartScriptCallback _createCallback(Runtime runtime, String libraryUri, String name) {
    return (ScriptContext context) async {
      final result = runtime.executeLib(
        libraryUri,
        name,
        <Object?>[$ScriptContext.wrap(context, _bindingHost)],
      );
      if (result is $Future) {
        await result.$value;
      } else if (result is Future) {
        await result;
      } else if (result is $Value) {
        final reified = result.$reified;
        if (reified is Future) {
          await reified;
        }
      }
    };
  }

  String _libraryUri(ScriptDescriptor descriptor) {
    return 'package:$_packageName/${descriptor.fileName}';
  }
}

const _packageName = 'optimascript';
const _apiLibraryUri = 'package:$_packageName/api.dart';
const _supportedCallbacks = <String>{
  'onWorkbookOpen',
  'onWorkbookClose',
  'onPageEnter',
  'onPageLeave',
  'onCellChanged',
  'onSelectionChanged',
  'onNotesChanged',
  'onInvoke',
};

const _apiStub = r'''
library optimascript.api;

import 'dart:async';

abstract class ScriptContext {
  ScriptApi get api;
  FutureOr<void> logMessage(String message);
  FutureOr<void> callHost(
    String name, {
    List<Object?> positional = const <Object?>[],
    Map<String, Object?>? named,
  });
}

abstract class ScriptApi {
  WorkbookApi get workbook;
}

abstract class WorkbookApi {
  List<String> get sheetNames;
  int get activeSheetIndex;
  SheetApi? get activeSheet;

  SheetApi? sheetByName(String name);
  SheetApi? sheetAt(int index);
  bool activateSheetByName(String name);
  bool activateSheetAt(int index);
}

abstract class SheetApi {
  String get name;
  int get rowCount;
  int get columnCount;

  bool activate();
  CellApi cellAt(int row, int column);
  CellApi? cellByLabel(String label);
  bool insertRow([int? index]);
  bool insertColumn([int? index]);
  bool clear();
}

abstract class CellApi {
  String get sheetName;
  int get row;
  int get column;
  String get label;
  Object? get value;
  String get text;
  bool get isEmpty;
  String get type;

  bool setValue(Object? value);
  bool clear();
}
''';

class _OptimaScriptPlugin implements EvalPlugin {
  _OptimaScriptPlugin(this._bindingHost);

  final DartBindingHost _bindingHost;

  @override
  String get identifier => 'optimascript';

  @override
  void configureForCompile(BridgeDeclarationRegistry registry) {
    registry.defineBridgeClass($ScriptContext.$declaration);
    registry.defineBridgeClass($ScriptApi.$declaration);
    registry.defineBridgeClass($WorkbookApi.$declaration);
    registry.defineBridgeClass($SheetApi.$declaration);
    registry.defineBridgeClass($CellApi.$declaration);
  }

  @override
  void configureForRuntime(Runtime runtime) {
    runtime.addTypeAutowrapper(
      (value) => value is ScriptContext
          ? $ScriptContext.wrap(value, _bindingHost)
          : null,
    );
    runtime.addTypeAutowrapper(
      (value) => value is ScriptApi ? $ScriptApi.wrap(value) : null,
    );
    runtime.addTypeAutowrapper(
      (value) => value is WorkbookApi ? $WorkbookApi.wrap(value) : null,
    );
    runtime.addTypeAutowrapper(
      (value) => value is SheetApi ? $SheetApi.wrap(value) : null,
    );
    runtime.addTypeAutowrapper(
      (value) => value is CellApi ? $CellApi.wrap(value) : null,
    );
  }
}

class $ScriptContext implements $Instance {
  $ScriptContext.wrap(this.$value, this._bindingHost)
      : _superclass = $Object($value);

  static const $type = BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'ScriptContext'));

  static final $declaration = BridgeClassDef(
    BridgeClassType($type, isAbstract: true),
    constructors: const {},
    methods: {
      'logMessage': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.future),
          ),
          params: const [
            BridgeParameter(
              'message',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.string),
              ),
              false,
            ),
          ],
          namedParams: const [],
        ),
      ),
      'callHost': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.future),
          ),
          params: const [
            BridgeParameter(
              'name',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.string),
              ),
              false,
            ),
          ],
          namedParams: const [
            BridgeParameter(
              'positional',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.list),
                nullable: false,
              ),
              true,
            ),
            BridgeParameter(
              'named',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.map),
                nullable: true,
              ),
              true,
            ),
          ],
        ),
      ),
    },
    getters: {
      'api': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'ScriptApi')),
          ),
        ),
      ),
    },
    wrap: true,
  );

  @override
  final ScriptContext $value;

  final DartBindingHost _bindingHost;
  final $Instance _superclass;

  @override
  ScriptContext get $reified => $value;

  @override
  int $getRuntimeType(Runtime runtime) => runtime.lookupType($type.spec!);

  @override
  $Value? $getProperty(Runtime runtime, String identifier) {
    switch (identifier) {
      case 'logMessage':
        return _logMessage;
      case 'callHost':
        return _callHost;
      case 'api':
        return $ScriptApi.wrap($value.api);
      default:
        return _superclass.$getProperty(runtime, identifier);
    }
  }

  @override
  void $setProperty(Runtime runtime, String identifier, $Value value) {
    _superclass.$setProperty(runtime, identifier, value);
  }

  static const $Function _logMessage = $Function(_invokeLogMessage);

  static $Value? _invokeLogMessage(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $ScriptContext;
    final raw = args.isEmpty ? null : args[0]?.$reified;
    final message = raw is String ? raw : raw?.toString() ?? '';
    final future = Future.sync(() => instance.$value.logMessage(message));
    return $Future.wrap(future.then((value) => value));
  }

  static const $Function _callHost = $Function(_invokeCallHost);

  static $Value? _invokeCallHost(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $ScriptContext;
    final nameRaw = args.isEmpty ? null : args[0]?.$reified;
    if (nameRaw is! String || nameRaw.isEmpty) {
      throw ArgumentError('callHost requiert un nom de fonction.');
    }
    final positional =
        args.length > 1 ? _reifyList(args[1]?.$reified) : <Object?>[];
    final named = args.length > 2 ? _reifyMap(args[2]?.$reified) : null;

    final function = instance._bindingHost.resolve(nameRaw);
    if (function == null) {
      throw StateError('Fonction hôte inconnue: $nameRaw');
    }

    final future = Future.sync(
      () => function(instance.$value, positional, named: named),
    );
    return $Future.wrap(future.then((value) => value));
  }

  static List<Object?> _reifyList(Object? value) {
    if (value is List) {
      return value
          .map((element) => element is $Value ? element.$reified : element)
          .toList(growable: false);
    }
    return const <Object?>[];
  }

  static Map<String, Object?>? _reifyMap(Object? value) {
    if (value is Map) {
      final result = <String, Object?>{};
      value.forEach((key, val) {
        if (key == null) {
          return;
        }
        final castKey = key is $Value ? key.$reified : key;
        if (castKey == null) {
          return;
        }
        result[castKey.toString()] = val is $Value ? val.$reified : val;
      });
      return result;
    }
    return null;
  }
}

class $ScriptApi implements $Instance {
  $ScriptApi.wrap(this.$value) : _superclass = $Object($value);

  static const $type = BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'ScriptApi'));

  static final $declaration = BridgeClassDef(
    BridgeClassType($type, isAbstract: true),
    constructors: const {},
    methods: const {},
    getters: {
      'workbook': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'WorkbookApi')),
          ),
        ),
      ),
    },
    wrap: true,
  );

  @override
  final ScriptApi $value;

  final $Instance _superclass;

  @override
  ScriptApi get $reified => $value;

  @override
  int $getRuntimeType(Runtime runtime) => runtime.lookupType($type.spec!);

  @override
  $Value? $getProperty(Runtime runtime, String identifier) {
    switch (identifier) {
      case 'workbook':
        return $WorkbookApi.wrap($value.workbook);
      default:
        return _superclass.$getProperty(runtime, identifier);
    }
  }

  @override
  void $setProperty(Runtime runtime, String identifier, $Value value) {
    _superclass.$setProperty(runtime, identifier, value);
  }
}

class $WorkbookApi implements $Instance {
  $WorkbookApi.wrap(this.$value) : _superclass = $Object($value);

  static const $type = BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'WorkbookApi'));

  static final $declaration = BridgeClassDef(
    BridgeClassType($type, isAbstract: true),
    constructors: const {},
    methods: {
      'sheetByName': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'SheetApi')),
            nullable: true,
          ),
          params: const [
            BridgeParameter(
              'name',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.string),
              ),
              false,
            ),
          ],
        ),
      ),
      'sheetAt': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'SheetApi')),
            nullable: true,
          ),
          params: const [
            BridgeParameter(
              'index',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.int),
              ),
              false,
            ),
          ],
        ),
      ),
      'activateSheetByName': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.bool),
          ),
          params: const [
            BridgeParameter(
              'name',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.string),
              ),
              false,
            ),
          ],
        ),
      ),
      'activateSheetAt': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.bool),
          ),
          params: const [
            BridgeParameter(
              'index',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.int),
              ),
              false,
            ),
          ],
        ),
      ),
    },
    getters: {
      'sheetNames': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(
              CoreTypes.list,
              [
                BridgeTypeAnnotation(BridgeTypeRef(CoreTypes.string)),
              ],
            ),
          ),
        ),
      ),
      'activeSheetIndex': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.int),
          ),
        ),
      ),
      'activeSheet': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'SheetApi')),
            nullable: true,
          ),
        ),
      ),
    },
    wrap: true,
  );

  @override
  final WorkbookApi $value;

  final $Instance _superclass;

  @override
  WorkbookApi get $reified => $value;

  @override
  int $getRuntimeType(Runtime runtime) => runtime.lookupType($type.spec!);

  @override
  $Value? $getProperty(Runtime runtime, String identifier) {
    switch (identifier) {
      case 'sheetNames':
        return wrapList<String>(
          $value.sheetNames,
          (element) => $String(element),
        );
      case 'activeSheetIndex':
        return $int($value.activeSheetIndex);
      case 'activeSheet':
        final sheet = $value.activeSheet;
        return sheet == null ? const $null() : $SheetApi.wrap(sheet);
      case 'sheetByName':
        return _sheetByName;
      case 'sheetAt':
        return _sheetAt;
      case 'activateSheetByName':
        return _activateByName;
      case 'activateSheetAt':
        return _activateAt;
      default:
        return _superclass.$getProperty(runtime, identifier);
    }
  }

  @override
  void $setProperty(Runtime runtime, String identifier, $Value value) {
    _superclass.$setProperty(runtime, identifier, value);
  }

  static const $Function _sheetByName = $Function(_invokeSheetByName);

  static $Value? _invokeSheetByName(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $WorkbookApi;
    final raw = args.isEmpty ? null : args[0]?.$reified;
    if (raw == null) {
      throw ArgumentError('sheetByName requiert un nom.');
    }
    final sheet = instance.$value.sheetByName(raw.toString());
    return sheet == null ? const $null() : $SheetApi.wrap(sheet);
  }

  static const $Function _sheetAt = $Function(_invokeSheetAt);

  static $Value? _invokeSheetAt(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $WorkbookApi;
    final raw = args.isEmpty ? null : args[0]?.$reified;
    if (raw is! int) {
      throw ArgumentError('sheetAt requiert un index entier.');
    }
    final sheet = instance.$value.sheetAt(raw);
    return sheet == null ? const $null() : $SheetApi.wrap(sheet);
  }

  static const $Function _activateByName = $Function(_invokeActivateByName);

  static $Value? _invokeActivateByName(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $WorkbookApi;
    final raw = args.isEmpty ? null : args[0]?.$reified;
    if (raw == null) {
      throw ArgumentError('activateSheetByName requiert un nom.');
    }
    final result = instance.$value.activateSheetByName(raw.toString());
    return $bool(result);
  }

  static const $Function _activateAt = $Function(_invokeActivateAt);

  static $Value? _invokeActivateAt(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $WorkbookApi;
    final raw = args.isEmpty ? null : args[0]?.$reified;
    if (raw is! int) {
      throw ArgumentError('activateSheetAt requiert un index entier.');
    }
    final result = instance.$value.activateSheetAt(raw);
    return $bool(result);
  }
}

class $SheetApi implements $Instance {
  $SheetApi.wrap(this.$value) : _superclass = $Object($value);

  static const $type = BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'SheetApi'));

  static final $declaration = BridgeClassDef(
    BridgeClassType($type, isAbstract: true),
    constructors: const {},
    methods: {
      'activate': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.bool),
          ),
        ),
      ),
      'cellAt': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'CellApi')),
          ),
          params: const [
            BridgeParameter(
              'row',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.int),
              ),
              false,
            ),
            BridgeParameter(
              'column',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.int),
              ),
              false,
            ),
          ],
        ),
      ),
      'cellByLabel': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'CellApi')),
            nullable: true,
          ),
          params: const [
            BridgeParameter(
              'label',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.string),
              ),
              false,
            ),
          ],
        ),
      ),
      'insertRow': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.bool),
          ),
          params: const [
            BridgeParameter(
              'index',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.int),
                nullable: true,
              ),
              true,
            ),
          ],
        ),
      ),
      'insertColumn': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.bool),
          ),
          params: const [
            BridgeParameter(
              'index',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.int),
                nullable: true,
              ),
              true,
            ),
          ],
        ),
      ),
      'clear': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.bool),
          ),
        ),
      ),
    },
    getters: {
      'name': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.string),
          ),
        ),
      ),
      'rowCount': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.int),
          ),
        ),
      ),
      'columnCount': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.int),
          ),
        ),
      ),
    },
    wrap: true,
  );

  @override
  final SheetApi $value;

  final $Instance _superclass;

  @override
  SheetApi get $reified => $value;

  @override
  int $getRuntimeType(Runtime runtime) => runtime.lookupType($type.spec!);

  @override
  $Value? $getProperty(Runtime runtime, String identifier) {
    switch (identifier) {
      case 'name':
        return $String($value.name);
      case 'rowCount':
        return $int($value.rowCount);
      case 'columnCount':
        return $int($value.columnCount);
      case 'activate':
        return _activate;
      case 'cellAt':
        return _cellAt;
      case 'cellByLabel':
        return _cellByLabel;
      case 'insertRow':
        return _insertRow;
      case 'insertColumn':
        return _insertColumn;
      case 'clear':
        return _clear;
      default:
        return _superclass.$getProperty(runtime, identifier);
    }
  }

  @override
  void $setProperty(Runtime runtime, String identifier, $Value value) {
    _superclass.$setProperty(runtime, identifier, value);
  }

  static const $Function _activate = $Function(_invokeActivate);

  static $Value? _invokeActivate(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $SheetApi;
    final result = instance.$value.activate();
    return $bool(result);
  }

  static const $Function _cellAt = $Function(_invokeCellAt);

  static $Value? _invokeCellAt(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $SheetApi;
    if (args.length < 2) {
      throw ArgumentError('cellAt requiert une ligne et une colonne.');
    }
    final rowRaw = args[0]?.$reified;
    final columnRaw = args[1]?.$reified;
    if (rowRaw is! int || columnRaw is! int) {
      throw ArgumentError('cellAt attend des index entiers.');
    }
    final cell = instance.$value.cellAt(rowRaw, columnRaw);
    return $CellApi.wrap(cell);
  }

  static const $Function _cellByLabel = $Function(_invokeCellByLabel);

  static $Value? _invokeCellByLabel(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $SheetApi;
    final raw = args.isEmpty ? null : args[0]?.$reified;
    if (raw == null) {
      throw ArgumentError('cellByLabel requiert un libellé.');
    }
    final cell = instance.$value.cellByLabel(raw.toString());
    return cell == null ? const $null() : $CellApi.wrap(cell);
  }

  static const $Function _insertRow = $Function(_invokeInsertRow);

  static $Value? _invokeInsertRow(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $SheetApi;
    final raw = args.isEmpty ? null : args[0]?.$reified;
    int? index;
    if (raw != null) {
      if (raw is int) {
        index = raw;
      } else {
        throw ArgumentError('insertRow attend un entier ou null.');
      }
    }
    final result = instance.$value.insertRow(index);
    return $bool(result);
  }

  static const $Function _insertColumn = $Function(_invokeInsertColumn);

  static $Value? _invokeInsertColumn(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $SheetApi;
    final raw = args.isEmpty ? null : args[0]?.$reified;
    int? index;
    if (raw != null) {
      if (raw is int) {
        index = raw;
      } else {
        throw ArgumentError('insertColumn attend un entier ou null.');
      }
    }
    final result = instance.$value.insertColumn(index);
    return $bool(result);
  }

  static const $Function _clear = $Function(_invokeClear);

  static $Value? _invokeClear(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $SheetApi;
    final result = instance.$value.clear();
    return $bool(result);
  }

}

class $CellApi implements $Instance {
  $CellApi.wrap(this.$value) : _superclass = $Object($value);

  static const $type = BridgeTypeRef(BridgeTypeSpec(_apiLibraryUri, 'CellApi'));

  static final $declaration = BridgeClassDef(
    BridgeClassType($type, isAbstract: true),
    constructors: const {},
    methods: {
      'setValue': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.bool),
          ),
          params: const [
            BridgeParameter(
              'value',
              BridgeTypeAnnotation(
                BridgeTypeRef(CoreTypes.dynamic),
                nullable: true,
              ),
              false,
            ),
          ],
        ),
      ),
      'clear': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.bool),
          ),
        ),
      ),
    },
    getters: {
      'sheetName': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.string),
          ),
        ),
      ),
      'row': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.int),
          ),
        ),
      ),
      'column': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.int),
          ),
        ),
      ),
      'label': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.string),
          ),
        ),
      ),
      'value': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.dynamic),
            nullable: true,
          ),
        ),
      ),
      'text': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.string),
          ),
        ),
      ),
      'isEmpty': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.bool),
          ),
        ),
      ),
      'type': BridgeMethodDef(
        BridgeFunctionDef(
          returns: BridgeTypeAnnotation(
            BridgeTypeRef(CoreTypes.string),
          ),
        ),
      ),
    },
    wrap: true,
  );

  @override
  final CellApi $value;

  final $Instance _superclass;

  @override
  CellApi get $reified => $value;

  @override
  int $getRuntimeType(Runtime runtime) => runtime.lookupType($type.spec!);

  @override
  $Value? $getProperty(Runtime runtime, String identifier) {
    switch (identifier) {
      case 'sheetName':
        return $String($value.sheetName);
      case 'row':
        return $int($value.row);
      case 'column':
        return $int($value.column);
      case 'label':
        return $String($value.label);
      case 'value':
        return _wrapValue($value.value);
      case 'text':
        return $String($value.text);
      case 'isEmpty':
        return $bool($value.isEmpty);
      case 'type':
        return $String($value.type);
      case 'setValue':
        return _setValue;
      case 'clear':
        return _clear;
      default:
        return _superclass.$getProperty(runtime, identifier);
    }
  }

  @override
  void $setProperty(Runtime runtime, String identifier, $Value value) {
    _superclass.$setProperty(runtime, identifier, value);
  }

  static const $Function _setValue = $Function(_invokeSetValue);

  static $Value? _invokeSetValue(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $CellApi;
    final raw = args.isEmpty ? null : args[0]?.$reified;
    final result = instance.$value.setValue(raw);
    return $bool(result);
  }

  static const $Function _clear = $Function(_invokeClearCell);

  static $Value? _invokeClearCell(
    Runtime runtime,
    $Value? target,
    List<$Value?> args,
  ) {
    final instance = target as $CellApi;
    final result = instance.$value.clear();
    return $bool(result);
  }

  static $Value? _wrapValue(Object? value) {
    if (value == null) {
      return const $null();
    }
    if (value is bool) {
      return $bool(value);
    }
    if (value is int) {
      return $int(value);
    }
    if (value is double) {
      return $double(value);
    }
    if (value is num) {
      return $double(value.toDouble());
    }
    return $String(value.toString());
  }
}
