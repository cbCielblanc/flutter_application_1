import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Configuration used to locate the Python runtime on the host machine.
class PythonRuntimeConfig {
  PythonRuntimeConfig({
    String? configFilePath,
    String? windowsDllPath,
    Map<String, String>? environment,
  })  : _configFilePath = configFilePath ?? _defaultConfigFilePath(),
        _windowsDllPath = windowsDllPath,
        _environment = environment ?? Platform.environment;

  /// Creates a configuration that resolves values from the current process
  /// environment and the default configuration file location.
  factory PythonRuntimeConfig.fromEnvironment({String? configFilePath}) {
    return PythonRuntimeConfig(configFilePath: configFilePath);
  }

  static const String _windowsDllEnvironmentVariable = 'PYTHON_FFI_WINDOWS_DLL';
  static const String _windowsDllConfigKey = 'windowsDllPath';

  final String? _configFilePath;
  final String? _windowsDllPath;
  final Map<String, String> _environment;

  static String _defaultConfigFilePath() {
    return p.join('scripts', 'python_runtime.json');
  }

  /// Returns a copy with a different Windows DLL path.
  PythonRuntimeConfig copyWith({
    String? windowsDllPath,
    String? configFilePath,
    Map<String, String>? environment,
  }) {
    return PythonRuntimeConfig(
      windowsDllPath: windowsDllPath ?? _windowsDllPath,
      configFilePath: configFilePath ?? _configFilePath,
      environment: environment ?? _environment,
    );
  }

  /// Resolves the path to the Python runtime DLL on Windows.
  Future<String?> resolveWindowsDllPath() async {
    final directValue = _windowsDllPath;
    if (directValue != null && directValue.isNotEmpty) {
      return directValue;
    }

    final envValue = _environment[_windowsDllEnvironmentVariable];
    if (envValue != null && envValue.isNotEmpty) {
      return envValue;
    }

    final settingsValue = await _readWindowsDllPathFromConfig();
    if (settingsValue != null && settingsValue.isNotEmpty) {
      return settingsValue;
    }

    return null;
  }

  Future<String?> _readWindowsDllPathFromConfig() async {
    final path = _configFilePath;
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    try {
      final contents = await file.readAsString();
      final decoded = jsonDecode(contents);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final value = decoded[_windowsDllConfigKey];
      if (value is String) {
        return value;
      }
    } on FormatException catch (error) {
      debugPrint('Invalid JSON in $path: $error');
    } on IOException catch (error) {
      debugPrint('Failed reading $path: $error');
    }
    return null;
  }
}