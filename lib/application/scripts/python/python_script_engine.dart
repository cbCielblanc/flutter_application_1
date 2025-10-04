import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:python_ffi_dart/python_ffi_dart.dart';

import '../scope.dart';

typedef PythonHostFunction = FutureOr<Object?> Function(
  List<Object?> positional, {
  Map<String, Object?>? named,
});

class PythonBindingHost {
  PythonBindingHost({
    Map<String, PythonHostFunction> functions = const <String, PythonHostFunction>{},
  }) : _functions = Map.unmodifiable(functions);

  final Map<String, PythonHostFunction> _functions;

  Map<String, PythonHostFunction> get functions => _functions;

  bool get isEmpty => _functions.isEmpty;

  PythonBindingHost copyWith({
    Map<String, PythonHostFunction>? functions,
  }) {
    if (functions == null) {
      return this;
    }
    return PythonBindingHost(functions: functions);
  }
}

class PythonScriptExport {
  PythonScriptExport({
    required this.name,
    required PythonFunction function,
  }) : _function = function;

  final String name;
  final PythonFunction _function;

  PythonFunction get function => _function;

  Future<T?> invoke<T extends Object?>(
    List<Object?> positional, {
    Map<String, Object?>? named,
  }) async {
    return _function.call<T>(positional, kwargs: named);
  }
}

class PythonScriptModule {
  PythonScriptModule({
    required this.moduleName,
    required this.scope,
    required this.sourcePath,
    required Map<String, PythonScriptExport> exports,
  }) : exports = Map.unmodifiable(exports);

  PythonScriptModule.empty({
    required this.moduleName,
    required this.scope,
    this.sourcePath = '',
  }) : exports = const <String, PythonScriptExport>{};

  final String moduleName;
  final ScriptScope scope;
  final String sourcePath;
  final Map<String, PythonScriptExport> exports;

  Iterable<String> get callableNames => exports.keys;

  PythonScriptExport? operator [](String name) => exports[name];
}

class PythonScriptEngine {
  PythonScriptEngine({PythonBindingHost? bindingHost})
      : _bindingHost = bindingHost ?? PythonBindingHost();

  final PythonBindingHost _bindingHost;

  Directory? _moduleCacheDirectory;
  bool _initialized = false;
  Object? _initializationError;

  Future<void> ensureInitialized({
    String? bundledPythonModules,
    String? libPath,
    bool? verboseLogging,
  }) async {
    if (_initialized) {
      return;
    }
    try {
      await PythonFfiDart.instance.initialize(
        pythonModules: bundledPythonModules,
        libPath: libPath,
        verboseLogging: verboseLogging,
      );
      await _installBindingHost();
      _initialized = true;
      _initializationError = null;
    } on UnsupportedError catch (error) {
      _initializationError = error;
      _initialized = true;
      debugPrint('Initialisation Python non supportée: $error');
    }
  }

  Future<PythonScriptModule> loadModule({
    required String id,
    required ScriptScope scope,
    required String source,
  }) async {
    await ensureInitialized();
    if (_initializationError != null) {
      throw _initializationError!;
    }
    final moduleName = _moduleNameFor(scope, id);
    final moduleFile = await _materializeModule(moduleName, source);
    await PythonFfiDart.instance.appendToPath(moduleFile.parent.path);

    // Always reload a module to pick up source changes.
    await _invalidateModuleCache(moduleName);

    final module = PythonModule.import<_DynamicPythonModule>(
      moduleName,
      _DynamicPythonModule.from,
    );

    final exports = await _discoverExports(module);
    return PythonScriptModule(
      moduleName: moduleName,
      scope: scope,
      sourcePath: moduleFile.path,
      exports: exports,
    );
  }

  Future<Map<String, PythonScriptExport>> _discoverExports(
    _DynamicPythonModule module,
  ) async {
    final builtins = PythonModule.import<_BuiltinsModule>(
      'builtins',
      _BuiltinsModule.from,
    );
    final dirEntries = builtins.dirFunction.call<List<Object?>>(<Object?>[module]);
    final callable = builtins.callableFunction;

    final exports = <String, PythonScriptExport>{};
    if (dirEntries == null) {
      return exports;
    }

    for (final entry in dirEntries) {
      if (entry is! String) {
        continue;
      }
      if (entry.startsWith('_')) {
        continue;
      }
      if (!module.hasAttribute(entry)) {
        continue;
      }
      final attribute = module.getAttributeRaw(entry);
      if (attribute == null) {
        continue;
      }
      final attributeObject = _DynamicPythonObject.from(attribute);
      final isCallable = callable.call<bool>(<Object?>[attributeObject]);
      if (isCallable != true) {
        continue;
      }
      try {
        final pythonFunction = _DynamicPythonFunction.from(
          module.getFunction(entry),
        );
        exports[entry] = PythonScriptExport(
          name: entry,
          function: pythonFunction,
        );
      } on PythonFfiException catch (error) {
        debugPrint('Impossible de lier la fonction $entry: $error');
      }
    }
    return exports;
  }

  Future<void> _installBindingHost() async {
    if (_bindingHost.isEmpty) {
      return;
    }
    final moduleSource = StringBuffer()
      ..writeln('import json')
      ..writeln('from typing import Any')
      ..writeln('import builtins as _builtins')
      ..writeln('')
      ..writeln('class _OptimaDartHost:')
      ..writeln('    def __init__(self):')
      ..writeln('        self._registry = {}')
      ..writeln('')
      ..writeln('    def register(self, name: str):')
      ..writeln('        def decorator(func):')
      ..writeln('            self._registry[name] = func')
      ..writeln('            return func')
      ..writeln('        return decorator')
      ..writeln('')
      ..writeln('    def call(self, name: str, *args: Any, **kwargs: Any):')
      ..writeln('        raise RuntimeError(')
      ..writeln('            "Dart host bridge is not wired; call from Dart instead."')
      ..writeln('        )')
      ..writeln('')
      ..writeln('host = _OptimaDartHost()');

    final definition = PythonModuleDefinition(
      name: 'optima_host',
      root: SourceDirectory('optima_host')
        ..add(
          SourceBase64(
            '__init__.py',
            base64.encode(utf8.encode(moduleSource.toString())),
          ),
        ),
    );
    await PythonFfiDart.instance.prepareModule(definition);
  }

  Future<void> _invalidateModuleCache(String moduleName) async {
    final importlib = PythonModule.import<_ImportlibModule>(
      'importlib',
      _ImportlibModule.from,
    );
    importlib.invalidateCaches.call<Object?>(const <Object?>[]);

    final builtins = PythonModule.import<_BuiltinsModule>(
      'builtins',
      _BuiltinsModule.from,
    );
    final execFunction = _DynamicPythonFunction.from(builtins.getFunction('exec'));
    execFunction.call<Object?>(<Object?>[
      "import sys\nsys.modules.pop('$moduleName', None)",
    ]);
  }

  Future<File> _materializeModule(String moduleName, String source) async {
    final directory = await _ensureModuleDirectory();
    final file = File(p.join(directory.path, '$moduleName.py'));
    await file.parent.create(recursive: true);
    await file.writeAsString(source);
    return file;
  }

  Future<Directory> _ensureModuleDirectory() async {
    if (_moduleCacheDirectory != null) {
      return _moduleCacheDirectory!;
    }
    if (kIsWeb) {
      throw UnsupportedError('Python runtime is not available on the web.');
    }
    final baseDir = await getApplicationSupportDirectory();
    final directory = Directory(p.join(baseDir.path, 'python_modules'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _moduleCacheDirectory = directory;
    return directory;
  }

  String _moduleNameFor(ScriptScope scope, String id) {
    final prefix = switch (scope) {
      ScriptScope.global => 'global',
      ScriptScope.page => 'page',
      ScriptScope.shared => 'shared',
    };
    final normalised = id.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'optima_${prefix}_$normalised';
  }
}

final class _DynamicPythonModule extends PythonModule {
  _DynamicPythonModule.from(
    PythonModuleInterface<PythonFfiDelegate<Object?>, Object?> delegate,
  ) : super.from(delegate);
}

final class _BuiltinsModule extends PythonModule {
  _BuiltinsModule.from(
    PythonModuleInterface<PythonFfiDelegate<Object?>, Object?> delegate,
  ) : super.from(delegate);

  PythonFunction get dirFunction => _DynamicPythonFunction.from(getFunction('dir'));

  PythonFunction get callableFunction =>
      _DynamicPythonFunction.from(getFunction('callable'));
}

final class _ImportlibModule extends PythonModule {
  _ImportlibModule.from(
    PythonModuleInterface<PythonFfiDelegate<Object?>, Object?> delegate,
  ) : super.from(delegate);

  PythonFunction get invalidateCaches =>
      _DynamicPythonFunction.from(getFunction('invalidate_caches'));
}

final class _DynamicPythonObject extends PythonObject {
  _DynamicPythonObject.from(
    PythonObjectInterface<PythonFfiDelegate<Object?>, Object?> delegate,
  ) : super.from(delegate);
}

final class _DynamicPythonFunction extends PythonFunction {
  _DynamicPythonFunction.from(
    PythonFunctionInterface<PythonFfiDelegate<Object?>, Object?> delegate,
  ) : super.from(delegate);
}
