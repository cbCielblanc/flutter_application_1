import 'dart:async';
import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';
import 'package:dart_eval/src/eval/compiler/errors.dart';

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
  FutureOr<void> logMessage(String message);
  FutureOr<void> callHost(
    String name, {
    List<Object?> positional = const <Object?>[],
    Map<String, Object?>? named,
  });
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
  }

  @override
  void configureForRuntime(Runtime runtime) {
    runtime.addTypeAutowrapper(
      (value) => value is ScriptContext
          ? $ScriptContext.wrap(value, _bindingHost)
          : null,
    );
  }
}

class $ScriptContext
    with $Bridge<ScriptContext>
    implements ScriptContext, $Instance {
  $ScriptContext.wrap(this.$value, this._bindingHost)
      : _superclass = $Object($value);

  static final $type = BridgeTypeSpec(_apiLibraryUri, 'ScriptContext').ref;

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
