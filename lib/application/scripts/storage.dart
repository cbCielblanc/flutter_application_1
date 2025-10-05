import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'dart/dart_script_engine.dart';
import 'models.dart';

class StoredScript {
  StoredScript({
    required this.descriptor,
    required this.source,
    required this.document,
    required this.origin,
    required this.isMutable,
  });

  final ScriptDescriptor descriptor;
  final String source;
  final ScriptDocument document;
  final String origin;
  final bool isMutable;

  Iterable<String> get exportNames => document.exportNames;

  DartScriptExport? export(String name) => document[name];

  Map<String, DartScriptExport> get exports => document.exports;

  Map<String, DartScriptSignature> get signatures => document.signatures;

  DartScriptSignature? signatureFor(String name) => document.signatureFor(name);

  Iterable<String> get signatureNames => document.signatureNames;

  StoredScript copyWith({
    String? source,
    ScriptDocument? document,
    String? origin,
    bool? isMutable,
  }) {
    return StoredScript(
      descriptor: descriptor,
      source: source ?? this.source,
      document: document ?? this.document,
      origin: origin ?? this.origin,
      isMutable: isMutable ?? this.isMutable,
    );
  }
}

class ScriptStorage {
  ScriptStorage({
    AssetBundle? bundle,
    DartScriptEngine? engine,
    DartBindingHost? bindingHost,
  })  : _bundle = bundle ?? rootBundle,
        _engine = engine ??
            DartScriptEngine(bindingHost: bindingHost ?? _defaultBindingHost());

  final AssetBundle _bundle;
  final DartScriptEngine _engine;
  final bool _supportsFileSystem = !kIsWeb;

  Directory? _writeDirectory;
  List<String>? _assetScriptPaths;
  Set<String>? _assetLegacyScriptPaths;
  final Map<String, _CachedDocument> _documentCache = <String, _CachedDocument>{};
  final Set<String> _legacyAssetScripts = <String>{};
  final Set<String> _legacyFileScripts = <String>{};
  bool _engineInitialised = false;

  List<String> get migrationWarnings {
    final warnings = <String>[];
    if (_legacyAssetScripts.isNotEmpty) {
      final assets = _legacyAssetScripts.toList()..sort();
      warnings.add(
        'Scripts Python hérités détectés dans les assets: '
        '${assets.join(', ')}. Ces scripts ne sont plus pris en charge. '
        'Importez-les dans l\'éditeur puis sauvegardez-les au format Dart (*.dart).',
      );
    }
    if (_legacyFileScripts.isNotEmpty) {
      final files = _legacyFileScripts.toList()..sort();
      warnings.add(
        'Scripts Python hérités détectés sur le disque: '
        '${files.join(', ')}. Renommez-les avec l\'extension .dart puis '
        'mettez-les à jour depuis l\'espace administrateur.',
      );
    }
    return warnings;
  }

  bool get supportsFileSystem => _supportsFileSystem;

  bool get isReadOnly => !_supportsFileSystem;

  Future<void> initialize({bool precompileAssets = false}) async {
    if (_engineInitialised) {
      return;
    }
    final assetScripts = await _listAssetScripts();
    if (precompileAssets && assetScripts.isNotEmpty) {
      for (final asset in assetScripts) {
        final descriptor = _descriptorFromAsset(asset);
        if (descriptor == null) {
          continue;
        }
        try {
          final source = await _bundle.loadString(asset);
          await _loadDocument(descriptor: descriptor, source: source);
        } on FlutterError {
          continue;
        }
      }
    }
    _engineInitialised = true;
  }

  Future<Directory?> _ensureWriteDirectory() async {
    if (!_supportsFileSystem) {
      return null;
    }
    if (_writeDirectory != null) {
      return _writeDirectory!;
    }
    final projectDir = Directory('scripts');
    if (await projectDir.exists()) {
      _writeDirectory = projectDir;
      return projectDir;
    }
    try {
      await projectDir.create(recursive: true);
      _writeDirectory = projectDir;
      return projectDir;
    } catch (_) {
      // Ignore and fallback to application support directory.
    }
    final support = await getApplicationSupportDirectory();
    final fallback = Directory('${support.path}/scripts');
    if (!await fallback.exists()) {
      await fallback.create(recursive: true);
    }
    _writeDirectory = fallback;
    return fallback;
  }

  Future<StoredScript?> loadScript(ScriptDescriptor descriptor) async {
    if (_supportsFileSystem) {
      final file = await _resolveFile(descriptor);
      if (file != null && await file.exists()) {
        final source = await file.readAsString();
        final document = await _loadDocument(
          descriptor: descriptor,
          source: source,
        );
        return StoredScript(
          descriptor: descriptor,
          source: source,
          document: document,
          origin: file.path,
          isMutable: true,
        );
      }
    }
    final assetPath = _assetPath(descriptor);
    try {
      final source = await _bundle.loadString(assetPath);
      final document = await _loadDocument(
        descriptor: descriptor,
        source: source,
      );
      return StoredScript(
        descriptor: descriptor,
        source: source,
        document: document,
        origin: 'asset:$assetPath',
        isMutable: false,
      );
    } on FlutterError {
      return null;
    }
  }

  Future<StoredScript> saveScript(
    ScriptDescriptor descriptor,
    String source, {
    ScriptDocument? validatedDocument,
  }) async {
    final document = validatedDocument ??
        await _loadDocument(
          descriptor: descriptor,
          source: source,
        );
    if (!_supportsFileSystem) {
      return StoredScript(
        descriptor: descriptor,
        source: source,
        document: document,
        origin: 'read-only (filesystem unsupported)',
        isMutable: false,
      );
    }
    final file = await _resolveFile(descriptor);
    if (file == null) {
      return StoredScript(
        descriptor: descriptor,
        source: source,
        document: document,
        origin: 'unavailable',
        isMutable: false,
      );
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(source);
    return StoredScript(
      descriptor: descriptor,
      source: source,
      document: document,
      origin: file.path,
      isMutable: true,
    );
  }

  Future<ScriptDocument> validateScript({
    required ScriptDescriptor descriptor,
    required String source,
  }) {
    return _loadDocument(
      descriptor: descriptor,
      source: source,
      strict: true,
    );
  }

  Future<List<StoredScript>> loadAll({ScriptScope? scope}) async {
    _legacyAssetScripts.clear();
    _legacyFileScripts.clear();
    final results = <StoredScript>[];
    final assets = await _listAssetScripts();
    for (final asset in assets) {
      final descriptor = _descriptorFromAsset(asset);
      if (descriptor == null) {
        continue;
      }
      if (scope != null && descriptor.scope != scope) {
        continue;
      }
      final script = await loadScript(descriptor);
      if (script != null) {
        results.add(script);
      }
    }
    // Include additional local files that may not exist in assets yet.
    final writeDir = await _ensureWriteDirectory();
    if (writeDir != null && await writeDir.exists()) {
      final basePath = writeDir.path;
      await for (final entity in writeDir.list(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final relative = entity.path
            .substring(basePath.length + 1)
            .replaceAll('\\', '/');
        if (relative.endsWith('.py')) {
          _legacyFileScripts.add(relative);
          continue;
        }
        if (!relative.endsWith('.dart')) {
          continue;
        }
        final descriptor = _descriptorFromRelative(relative);
        if (descriptor == null) {
          continue;
        }
        if (scope != null && descriptor.scope != scope) {
          continue;
        }
        final existing = results.any(
          (script) =>
              script.descriptor.scope == descriptor.scope &&
              script.descriptor.key == descriptor.key,
        );
        if (existing) {
          continue;
        }
        final source = await entity.readAsString();
        final document = await _loadDocument(
          descriptor: descriptor,
          source: source,
        );
        results.add(
          StoredScript(
            descriptor: descriptor,
            source: source,
            document: document,
            origin: entity.path,
            isMutable: true,
          ),
        );
      }
    }
    return results;
  }

  Future<File?> _resolveFile(ScriptDescriptor descriptor) async {
    final writeDir = await _ensureWriteDirectory();
    if (writeDir == null) {
      return null;
    }
    return File('${writeDir.path}/${descriptor.fileName}');
  }

  String _assetPath(ScriptDescriptor descriptor) {
    return 'assets/scripts/${descriptor.fileName}';
  }

  Future<List<String>> _listAssetScripts() async {
    if (_assetScriptPaths != null) {
      final cachedLegacy = _assetLegacyScriptPaths;
      if (cachedLegacy != null && cachedLegacy.isNotEmpty) {
        _legacyAssetScripts.addAll(cachedLegacy);
      }
      return _assetScriptPaths!;
    }
    try {
      final manifest = await _bundle.loadString('AssetManifest.json');
      final decoded = json.decode(manifest);
      if (decoded is! Map<String, dynamic>) {
        _assetScriptPaths = const <String>[];
        _assetLegacyScriptPaths = const <String>{};
        return _assetScriptPaths!;
      }
      final scripts = <String>[];
      final legacy = <String>{};
      decoded.forEach((key, value) {
        if (!key.startsWith('assets/scripts/')) {
          return;
        }
        if (key.endsWith('.dart')) {
          scripts.add(key);
          return;
        }
        if (key.endsWith('.py')) {
          final relative = key.replaceFirst('assets/scripts/', '');
          legacy.add(relative);
          _legacyAssetScripts.add(relative);
        }
      });
      _assetScriptPaths = scripts;
      _assetLegacyScriptPaths = legacy;
      return scripts;
    } catch (_) {
      _assetScriptPaths = const <String>[];
      _assetLegacyScriptPaths = const <String>{};
      return _assetScriptPaths!;
    }
  }

  ScriptDescriptor? _descriptorFromAsset(String assetPath) {
    final relative = assetPath.replaceFirst('assets/scripts/', '');
    return _descriptorFromRelative(relative);
  }

  ScriptDescriptor? _descriptorFromRelative(String relativePath) {
    final segments = relativePath.split('/');
    if (segments.length != 2) {
      return null;
    }
    final scopeSegment = segments.first;
    final fileName = segments.last;
    if (!fileName.endsWith('.dart')) {
      return null;
    }
    final key = fileName.substring(0, fileName.length - 5);
    switch (scopeSegment) {
      case 'global':
        return ScriptDescriptor(scope: ScriptScope.global, key: key);
      case 'pages':
        return ScriptDescriptor(scope: ScriptScope.page, key: key);
      case 'shared':
        return ScriptDescriptor(scope: ScriptScope.shared, key: key);
      default:
        return null;
    }
  }

  Future<ScriptDocument> _loadDocument({
    required ScriptDescriptor descriptor,
    required String source,
    bool strict = false,
  }) async {
    final cacheKey = _cacheKey(descriptor);
    final signature = source.hashCode;
    final cached = _documentCache[cacheKey];
    if (cached != null && cached.matches(signature, source)) {
      return cached.document;
    }

    DartScriptModule module;
    Map<String, DartScriptExport> exports;
    Map<String, DartScriptSignature> signatures;

    try {
      module = await _engine.loadModule(
        descriptor: descriptor,
        source: source,
      );
      exports = Map<String, DartScriptExport>.from(module.exports);
      signatures = Map<String, DartScriptSignature>.from(module.signatures);
    } on DartScriptCompilationException catch (error, stackTrace) {
      debugPrint(
        'Erreur lors de l\'analyse du module ${descriptor.fileName}: $error\n$stackTrace',
      );
      if (strict) {
        throw ScriptValidationException(error.message);
      }
      module = DartScriptModule(
        descriptor: descriptor,
        source: source,
        exports: const <String, DartScriptExport>{},
        signatures: const <String, DartScriptSignature>{},
      );
      exports = const <String, DartScriptExport>{};
      signatures = const <String, DartScriptSignature>{};
    } catch (error, stackTrace) {
      debugPrint(
        'Erreur inattendue lors du chargement du module ${descriptor.fileName}: '
        '$error\n$stackTrace',
      );
      if (strict) {
        throw ScriptValidationException(
          'Erreur inattendue lors du chargement du module ${descriptor.fileName}: '
          '$error',
        );
      }
      module = DartScriptModule(
        descriptor: descriptor,
        source: source,
        exports: const <String, DartScriptExport>{},
        signatures: const <String, DartScriptSignature>{},
      );
      exports = const <String, DartScriptExport>{};
      signatures = const <String, DartScriptSignature>{};
    }

    final document = ScriptDocument(
      id: descriptor.key,
      name: descriptor.key,
      scope: descriptor.scope,
      module: module,
      exports: exports,
      signatures: signatures,
    );
    _documentCache[cacheKey] = _CachedDocument(
      signature: signature,
      source: source,
      document: document,
    );
    return document;
  }

  String _cacheKey(ScriptDescriptor descriptor) =>
      '${descriptor.scope.name}:${descriptor.key}';
}

class _CachedDocument {
  const _CachedDocument({
    required this.signature,
    required this.source,
    required this.document,
  });

  final int signature;
  final String source;
  final ScriptDocument document;

  bool matches(int otherSignature, String otherSource) {
    return signature == otherSignature && source == otherSource;
  }
}

class ScriptValidationException implements Exception {
  ScriptValidationException(this.message, {this.allowSave = false});

  final String message;
  final bool allowSave;

  @override
  String toString() => message;
}

DartBindingHost _defaultBindingHost() {
  return DartBindingHost(
    functions: <String, DartHostFunction>{
      'log': (context, positional, {named}) async {
        final message =
            positional.isEmpty ? '' : positional.first?.toString() ?? '';
        await context.logMessage(message);
      },
    },
  );
}

