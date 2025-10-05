import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/application/scripts/storage.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle({String manifest = '{}', Map<String, String> assets = const <String, String>{}})
      : _manifest = manifest,
        _assets = assets;

  final String _manifest;
  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key, {bool cache = true}) async {
    if (key == 'AssetManifest.json') {
      final bytes = Uint8List.fromList(utf8.encode(_manifest));
      return ByteData.view(bytes.buffer);
    }
    final asset = _assets[key];
    if (asset != null) {
      final bytes = Uint8List.fromList(utf8.encode(asset));
      return ByteData.view(bytes.buffer);
    }
    throw FlutterError('Unable to load asset: $key');
  }

  @override
  Future<ImmutableBuffer> loadBuffer(String key) async {
    final data = await load(key);
    return ImmutableBuffer.fromUint8List(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (key == 'AssetManifest.json') {
      return _manifest;
    }
    final asset = _assets[key];
    if (asset != null) {
      return asset;
    }
    throw FlutterError('Unable to load asset: $key');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScriptStorage migration', () {
    test('detects legacy python scripts on disk', () async {
      final legacy = File('scripts/global/legacy_test.py');
      if (await legacy.exists()) {
        await legacy.delete();
      }
      await legacy.create(recursive: true);
      await legacy.writeAsString('# legacy python script');
      addTearDown(() async {
        if (await legacy.exists()) {
          await legacy.delete();
        }
      });

      final storage = ScriptStorage(bundle: _FakeAssetBundle());
      await storage.loadAll();

      expect(storage.migrationWarnings, isNotEmpty);
      expect(
        storage.migrationWarnings.join('\n'),
        contains('global/legacy_test.py'),
      );
    });

    test('detects legacy python scripts in assets', () async {
      final manifest = jsonEncode(<String, List<String>>{
        'assets/scripts/global/legacy.py': <String>['assets/scripts/global/legacy.py'],
        'assets/scripts/global/valid.dart': <String>['assets/scripts/global/valid.dart'],
      });
      final bundle = _FakeAssetBundle(
        manifest: manifest,
        assets: <String, String>{
          'assets/scripts/global/valid.dart': '{}',
        },
      );

      final storage = ScriptStorage(bundle: bundle);
      await storage.loadAll();

      expect(storage.migrationWarnings, isNotEmpty);
      expect(
        storage.migrationWarnings.join('\n'),
        contains('global/legacy.py'),
      );
    });
  });
}
