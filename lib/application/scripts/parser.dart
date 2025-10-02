import 'package:yaml/yaml.dart';

import 'models.dart';

class ScriptParser {
  ScriptDocument parse({
    required String id,
    required String source,
    ScriptScope? forcedScope,
  }) {
    final node = loadYaml(source);
    if (node is! YamlMap) {
      throw ScriptParseException(
        'Le script $id doit commencer par une map YAML.',
      );
    }
    final map = _toNativeMap(node);
    final name = (map['name'] as String?)?.trim();
    final scopeLabel = (map['scope'] as String?)?.trim();
    final scope = forcedScope ?? _parseScope(scopeLabel);
    final imports = _parseStringList(map['imports']);
    final snippets = _parseSnippets(map['snippets']);
    final handlers = _parseHandlers(map['handlers']);
    return ScriptDocument(
      id: id,
      name: name?.isNotEmpty == true ? name! : id,
      scope: scope,
      imports: imports,
      snippets: {for (final snippet in snippets) snippet.name: snippet},
      handlers: handlers,
    );
  }

  List<ScriptHandler> _parseHandlers(dynamic value) {
    if (value == null) {
      return const <ScriptHandler>[];
    }
    final list = value as List?;
    if (list == null) {
      throw ScriptParseException('Le champ handlers doit etre une liste.');
    }
    final handlers = <ScriptHandler>[];
    for (final entry in list) {
      if (entry is! Map) {
        throw ScriptParseException('Chaque handler doit etre une map.');
      }
      final eventLabel = entry['event'];
      if (eventLabel is! String || eventLabel.isEmpty) {
        throw ScriptParseException('Chaque handler doit definir un event.');
      }
      final eventType = ScriptEventTypeLabel.parse(eventLabel);
      final filtersRaw = entry['filter'] ?? entry['when'];
      final filters = filtersRaw is Map
          ? Map<String, Object?>.fromEntries(
              filtersRaw.entries.map(
                (MapEntry<dynamic, dynamic> e) => MapEntry<String, Object?>(
                  e.key.toString(),
                  _toNative(e.value),
                ),
              ),
            )
          : const <String, Object?>{};
      final description = entry['description'] as String?;
      final actions = _parseActions(entry['actions']);
      handlers.add(
        ScriptHandler(
          eventType: eventType,
          filters: filters,
          actions: actions,
          description: description,
        ),
      );
    }
    return handlers;
  }

  List<ScriptAction> _parseActions(dynamic value) {
    if (value == null) {
      return const <ScriptAction>[];
    }
    final list = value as List?;
    if (list == null) {
      throw ScriptParseException('Le champ actions doit etre une liste.');
    }
    final actions = <ScriptAction>[];
    for (final entry in list) {
      if (entry is Map) {
        if (entry.containsKey('type')) {
          final type = entry['type'];
          if (type is! String || type.isEmpty) {
            throw ScriptParseException(
              'Le champ type est requis pour une action.',
            );
          }
          final description = entry['description'] as String?;
          final params = <String, Object?>{};
          entry.forEach((dynamic key, dynamic value) {
            if (key == 'type' || key == 'description') {
              return;
            }
            params[key.toString()] = _toNative(value);
          });
          actions.add(
            ScriptAction(
              type: type,
              parameters: params,
              description: description,
            ),
          );
          continue;
        }
        if (entry.length == 1) {
          final key = entry.keys.first;
          if (key is! String || key.isEmpty) {
            throw ScriptParseException(
              'Les cles des actions doivent etre des chaines.',
            );
          }
          final value = entry.values.first;
          if (value == null) {
            actions.add(ScriptAction(type: key));
          } else if (value is Map) {
            actions.add(
              ScriptAction(
                type: key,
                parameters: Map<String, Object?>.fromEntries(
                  value.entries.map(
                    (MapEntry<dynamic, dynamic> e) => MapEntry<String, Object?>(
                      e.key.toString(),
                      _toNative(e.value),
                    ),
                  ),
                ),
              ),
            );
          } else {
            actions.add(
              ScriptAction(
                type: key,
                parameters: <String, Object?>{'value': _toNative(value)},
              ),
            );
          }
          continue;
        }
      }
      throw ScriptParseException('Action invalide: $entry');
    }
    return actions;
  }

  List<ScriptSnippet> _parseSnippets(dynamic value) {
    if (value == null) {
      return const <ScriptSnippet>[];
    }
    final map = value as Map?;
    if (map == null) {
      throw ScriptParseException('Le champ snippets doit etre une map.');
    }
    final snippets = <ScriptSnippet>[];
    map.forEach((dynamic key, dynamic val) {
      if (key is! String || key.isEmpty) {
        throw ScriptParseException('Chaque snippet doit avoir un nom.');
      }
      String? description;
      dynamic actionsNode = val;
      if (val is Map && val.containsKey('actions')) {
        description = val['description'] as String?;
        actionsNode = val['actions'];
      }
      final actions = _parseActions(actionsNode);
      snippets.add(
        ScriptSnippet(name: key, actions: actions, description: description),
      );
    });
    return snippets;
  }

  ScriptScope _parseScope(String? value) {
    switch (value) {
      case 'global':
        return ScriptScope.global;
      case 'shared':
        return ScriptScope.shared;
      case 'page':
      case null:
        return ScriptScope.page;
      default:
        throw ScriptParseException('Scope inconnu: $value');
    }
  }

  List<String> _parseStringList(dynamic value) {
    if (value == null) {
      return const <String>[];
    }
    final list = value as List?;
    if (list == null) {
      throw ScriptParseException('Le champ imports doit etre une liste.');
    }
    return list.map((item) => item.toString()).toList(growable: false);
  }

  Map<String, Object?> _toNativeMap(YamlMap node) {
    return Map<String, Object?>.fromEntries(
      node.nodes.entries.map(
        (MapEntry<dynamic, YamlNode> entry) => MapEntry<String, Object?>(
          entry.key.toString(),
          _toNative(entry.value.value),
        ),
      ),
    );
  }

  Object? _toNative(Object? value) {
    if (value is YamlMap) {
      return Map<String, Object?>.fromEntries(
        value.entries.map(
          (MapEntry<dynamic, dynamic> entry) => MapEntry<String, Object?>(
            entry.key.toString(),
            _toNative(entry.value),
          ),
        ),
      );
    }
    if (value is YamlList) {
      return value.map(_toNative).toList();
    }
    return value;
  }
}
