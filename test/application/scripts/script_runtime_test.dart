import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/application/commands/workbook_command_manager.dart';
import 'package:flutter_application_1/application/scripts/context.dart';
import 'package:flutter_application_1/application/scripts/dart/dart_script_engine.dart';
import 'package:flutter_application_1/application/scripts/models.dart';
import 'package:flutter_application_1/application/scripts/runtime.dart';
import 'package:flutter_application_1/application/scripts/storage.dart';
import 'package:flutter_application_1/domain/sheet.dart';
import 'package:flutter_application_1/domain/workbook.dart';

class _InMemoryScriptStorage extends ScriptStorage {
  _InMemoryScriptStorage({Map<String, StoredScript>? scripts})
      : _scripts = Map<String, StoredScript>.from(scripts ?? <String, StoredScript>{}),
        super(bundle: _FakeAssetBundle());

  final Map<String, StoredScript> _scripts;
  bool initializeCalled = false;
  bool precompileRequested = false;

  void addScript(StoredScript script) {
    _scripts[_cacheKey(script.descriptor)] = script;
  }

  @override
  Future<void> initialize({bool precompileAssets = false}) async {
    initializeCalled = true;
    precompileRequested = precompileAssets;
  }

  @override
  Future<StoredScript?> loadScript(ScriptDescriptor descriptor) async {
    return _scripts[_cacheKey(descriptor)];
  }

  static String _cacheKey(ScriptDescriptor descriptor) =>
      '${descriptor.scope.name}:${descriptor.key}';
}

class _FakeAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData(0);

  @override
  Future<ImmutableBuffer> loadBuffer(String key) async {
    final data = await load(key);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return ImmutableBuffer.fromUint8List(bytes);
  }
}

StoredScript _createStoredScript({
  required ScriptDescriptor descriptor,
  required Map<String, DartScriptCallback> callbacks,
}) {
  final exports = <String, DartScriptExport>{
    for (final entry in callbacks.entries)
      entry.key: DartScriptExport(name: entry.key, callback: entry.value),
  };
  final signatures = <String, DartScriptSignature>{
    for (final name in callbacks.keys)
      name: DartScriptSignature(),
  };
  final module = DartScriptModule(
    descriptor: descriptor,
    source: '{}',
    exports: exports,
    signatures: signatures,
  );
  final document = ScriptDocument(
    id: descriptor.key,
    name: descriptor.key,
    scope: descriptor.scope,
    module: module,
    exports: exports,
    signatures: signatures,
  );
  return StoredScript(
    descriptor: descriptor,
    source: '{}',
    document: document,
    origin: 'memory',
    isMutable: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScriptRuntime', () {
    late Workbook workbook;
    late WorkbookCommandManager commandManager;

    setUp(() {
      workbook = Workbook(
        pages: <Sheet>[
          Sheet.fromRows(name: 'Feuille', rows: const <List<Object?>>[<Object?>[null]]),
        ],
      );
      commandManager = WorkbookCommandManager(initialWorkbook: workbook);
    });

    test('dispatches workbook open events to registered scripts', () async {
      final storage = _InMemoryScriptStorage();
      final descriptor = const ScriptDescriptor(scope: ScriptScope.global, key: 'default');
      final calls = <String>[];
      storage.addScript(
        _createStoredScript(
          descriptor: descriptor,
          callbacks: <String, DartScriptCallback>{
            'onWorkbookOpen': (ScriptContext context) {
              calls.add(context.eventType.wireName);
              return context.logMessage('log:${context.descriptor.key}');
            },
          },
        ),
      );

      final logs = <String>[];
      final runtime = ScriptRuntime(
        storage: storage,
        commandManager: commandManager,
        logSink: (message) => logs.add(message),
      );

      await runtime.dispatchWorkbookOpen();

      expect(storage.initializeCalled, isTrue);
      expect(storage.precompileRequested, isTrue);
      expect(calls, contains('workbook.open'));
      expect(logs, contains('log:default'));
    });

    test('supports synchronous callbacks returning void', () async {
      final storage = _InMemoryScriptStorage();
      final descriptor = const ScriptDescriptor(scope: ScriptScope.global, key: 'default');
      var invoked = false;
      storage.addScript(
        _createStoredScript(
          descriptor: descriptor,
          callbacks: <String, DartScriptCallback>{
            'onWorkbookOpen': (ScriptContext context) {
              invoked = true;
            },
          },
        ),
      );

      final runtime = ScriptRuntime(
        storage: storage,
        commandManager: commandManager,
      );

      await runtime.dispatchWorkbookOpen();

      expect(invoked, isTrue);
    });

    test('propagates errors thrown by callbacks with formatted logs', () async {
      final storage = _InMemoryScriptStorage();
      final descriptor = const ScriptDescriptor(scope: ScriptScope.global, key: 'default');
      storage.addScript(
        _createStoredScript(
          descriptor: descriptor,
          callbacks: <String, DartScriptCallback>{
            'onWorkbookOpen': (ScriptContext context) {
              throw StateError('boom');
            },
          },
        ),
      );

      final logs = <String>[];
      final runtime = ScriptRuntime(
        storage: storage,
        commandManager: commandManager,
        logSink: (message) => logs.add(message),
      );

      final previousOnError = FlutterError.onError;
      final captured = <FlutterErrorDetails>[];
      FlutterError.onError = (details) => captured.add(details);
      addTearDown(() {
        FlutterError.onError = previousOnError;
      });

      await expectLater(
        runtime.dispatchWorkbookOpen(),
        throwsA(isA<StateError>()),
      );

      expect(logs, isNotEmpty);
      expect(logs.first, contains('Erreur script détectée'));
      expect(logs.first, contains('Callback : onWorkbookOpen'));
      expect(logs.first, contains('Exception: StateError: boom'));
      expect(captured, isNotEmpty);
      expect(captured.first.exception, isA<StateError>());
    });
  });
}
