import 'dart:async';
import 'dart:collection';
import 'dart:convert';

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
  DartScriptSignature({
    Iterable<String> hostFunctions = const <String>[],
  }) : hostFunctions = List.unmodifiable(hostFunctions);

  final List<String> hostFunctions;

  bool get isEmpty => hostFunctions.isEmpty;
}

/// Container for the compiled representation of a script.
class DartScriptModule {
  DartScriptModule({
    required this.descriptor,
    required this.source,
    required Map<String, DartScriptExport> exports,
    required Map<String, DartScriptSignature> signatures,
  })  : exports = Map.unmodifiable(exports),
        signatures = Map.unmodifiable(signatures);

  final ScriptDescriptor descriptor;
  final String source;
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

  Future<DartScriptModule> loadModule({
    required ScriptDescriptor descriptor,
    required String source,
  }) async {
    Map<String, Object?> definition;
    try {
      final decoded = source.trim().isEmpty ? <String, Object?>{} : jsonDecode(source);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Une racine de type objet est requise.');
      }
      definition = Map<String, Object?>.from(decoded);
    } on FormatException catch (error) {
      throw DartScriptCompilationException(
        'Script ${descriptor.fileName} invalide: ${error.message}',
        cause: error,
      );
    } catch (error) {
      throw DartScriptCompilationException(
        'Script ${descriptor.fileName} invalide: $error',
        cause: error,
      );
    }

    final exports = <String, DartScriptExport>{};
    final signatures = <String, DartScriptSignature>{};
    definition.forEach((name, value) {
      if (value == null) {
        return;
      }
      final actions = _normaliseActions(value);
      exports[name] = DartScriptExport(
        name: name,
        callback: _callbackForActions(actions),
      );
      signatures[name] = DartScriptSignature(
        hostFunctions: _collectHostFunctions(actions),
      );
    });

    return DartScriptModule(
      descriptor: descriptor,
      source: source,
      exports: exports,
      signatures: signatures,
    );
  }

  DartScriptCallback _callbackForActions(List<Object?> actions) {
    return (ScriptContext context) async {
      for (final action in actions) {
        await _executeAction(context, action);
      }
    };
  }

  List<Object?> _normaliseActions(Object? definition) {
    if (definition == null) {
      return const <Object?>[];
    }
    if (definition is List) {
      return List<Object?>.from(definition);
    }
    return <Object?>[definition];
  }

  List<String> _collectHostFunctions(List<Object?> actions) {
    final functions = LinkedHashSet<String>();

    void visit(Object? action) {
      if (action == null) {
        return;
      }
      if (action is List) {
        for (final step in action) {
          visit(step);
        }
        return;
      }
      if (action is String) {
        if (action.isNotEmpty) {
          functions.add(action);
        }
        return;
      }
      if (action is Map) {
        final map = Map<Object?, Object?>.from(action);
        final rawName = map['call'] ?? map['function'];
        if (rawName is String && rawName.isNotEmpty) {
          functions.add(rawName);
        }
        return;
      }
    }

    for (final action in actions) {
      visit(action);
    }

    return List<String>.unmodifiable(functions);
  }

  Future<void> _executeAction(ScriptContext context, Object? action) async {
    if (action == null) {
      return;
    }
    if (action is List) {
      for (final step in action) {
        await _executeAction(context, step);
      }
      return;
    }
    if (action is String) {
      await _invokeHost(action, context, const <Object?>[], null);
      return;
    }
    if (action is Map) {
      final map = Map<Object?, Object?>.from(action);
      final rawName = map['call'] ?? map['function'];
      if (rawName is! String || rawName.isEmpty) {
        throw DartScriptCompilationException(
          'Action invalide: aucune fonction hôte définie.',
        );
      }
      final args = map['args'];
      final positional = args is List
          ? List<Object?>.from(args)
          : const <Object?>[];
      final named = map['named'];
      Map<String, Object?>? namedArgs;
      if (named is Map) {
        namedArgs = <String, Object?>{};
        named.forEach((key, value) {
          if (key == null) {
            return;
          }
          namedArgs![key.toString()] = value;
        });
      }
      await _invokeHost(rawName, context, positional, namedArgs);
      if (map.containsKey('then')) {
        await _executeAction(context, map['then']);
      }
      return;
    }

    throw DartScriptCompilationException(
      'Action ${action.runtimeType} non prise en charge dans ${context.descriptor.key}.',
    );
  }

  Future<void> _invokeHost(
    String name,
    ScriptContext context,
    List<Object?> positional,
    Map<String, Object?>? named,
  ) async {
    final function = _bindingHost.resolve(name);
    if (function == null) {
      throw DartScriptCompilationException(
        'Fonction hôte inconnue: $name',
      );
    }
    await function(context, positional, named: named);
  }
}
