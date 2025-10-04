import 'package:meta/meta.dart';

import 'workbook_page.dart';

/// Represents a structured entry in a [MenuPage] tree.
@immutable
class MenuTreeNode {
  const MenuTreeNode._({
    required this.id,
    required this.label,
    required List<MenuTreeNode> children,
    this.pageName,
  }) : _children = List<MenuTreeNode>.unmodifiable(children);

  /// Builds a section node containing the provided [children].
  factory MenuTreeNode.section({
    required String id,
    required String label,
    List<MenuTreeNode> children = const [],
  }) {
    return MenuTreeNode._(
      id: id,
      label: label,
      children: children,
    );
  }

  /// Builds a leaf node targeting a workbook page by [pageName].
  factory MenuTreeNode.leaf({
    required String id,
    required String label,
    required String pageName,
  }) {
    return MenuTreeNode._(
      id: id,
      label: label,
      children: const [],
      pageName: pageName,
    );
  }

  /// Attempts to build a node from serialised [data].
  static MenuTreeNode? tryParse(Object? data) {
    if (data is! Map<String, Object?>) {
      return null;
    }
    final id = data['id']?.toString();
    final label = data['label']?.toString();
    if (id == null || label == null) {
      return null;
    }
    final pageName = data['page']?.toString();
    final childrenData = data['children'];
    if (pageName != null) {
      return MenuTreeNode.leaf(id: id, label: label, pageName: pageName);
    }
    final children = <MenuTreeNode>[];
    if (childrenData is List) {
      for (final entry in childrenData) {
        final parsed = MenuTreeNode.tryParse(entry);
        if (parsed != null) {
          children.add(parsed);
        }
      }
    }
    return MenuTreeNode.section(id: id, label: label, children: children);
  }

  /// Unique identifier for stateful UI elements.
  final String id;

  /// User-facing label for the section or leaf.
  final String label;

  final List<MenuTreeNode> _children;

  /// Child nodes when representing a section.
  List<MenuTreeNode> get children => _children;

  /// Name of the targeted workbook page for leaf nodes.
  final String? pageName;

  /// Whether this node represents a leaf targeting a workbook page.
  bool get isLeaf => pageName != null;

  /// Serialises the node to a JSON-compatible representation.
  Map<String, Object?> toMetadata() {
    return {
      'id': id,
      'label': label,
      if (pageName != null) 'page': pageName,
      if (_children.isNotEmpty)
        'children': _children.map((child) => child.toMetadata()).toList(),
    };
  }
}

/// Container for the tree displayed by a [MenuPage].
@immutable
class MenuTree {
  const MenuTree({List<MenuTreeNode> nodes = const []})
      : _nodes = List<MenuTreeNode>.unmodifiable(nodes);

  const MenuTree.empty() : _nodes = const [];

  /// Attempts to build a tree from serialised [data].
  factory MenuTree.fromMetadata(Object? data) {
    if (data is Map<String, Object?>) {
      final rawNodes = data['nodes'] ?? data['children'] ?? data['sections'];
      if (rawNodes is List) {
        return MenuTree(nodes: _parseNodeList(rawNodes));
      }
    } else if (data is List) {
      return MenuTree(nodes: _parseNodeList(data));
    }
    return const MenuTree.empty();
  }

  /// Builds a simple tree grouping existing workbook pages.
  factory MenuTree.fromWorkbookPages(Iterable<WorkbookPage> pages) {
    final leaves = <MenuTreeNode>[];
    for (final page in pages) {
      if (page is MenuPage) {
        continue;
      }
      leaves.add(
        MenuTreeNode.leaf(
          id: 'page-${page.name}',
          label: page.name,
          pageName: page.name,
        ),
      );
    }
    if (leaves.isEmpty) {
      return const MenuTree.empty();
    }
    return MenuTree(
      nodes: [
        MenuTreeNode.section(
          id: 'root-pages',
          label: 'Pages',
          children: leaves,
        ),
      ],
    );
  }

  static List<MenuTreeNode> _parseNodeList(List<Object?> data) {
    final nodes = <MenuTreeNode>[];
    for (final entry in data) {
      final parsed = MenuTreeNode.tryParse(entry);
      if (parsed != null) {
        nodes.add(parsed);
      }
    }
    return nodes;
  }

  final List<MenuTreeNode> _nodes;

  /// Top-level nodes of the menu tree.
  List<MenuTreeNode> get nodes => _nodes;

  /// Whether the tree currently exposes any node.
  bool get isEmpty => _nodes.isEmpty;

  /// Convenience getter mirroring [isEmpty].
  bool get isNotEmpty => _nodes.isNotEmpty;

  /// Serialises the tree to a JSON-compatible representation.
  Map<String, Object?> toMetadata() {
    return {
      'nodes': _nodes.map((node) => node.toMetadata()).toList(),
    };
  }
}

/// Represents a navigational menu page in the workbook.
@immutable
class MenuPage extends WorkbookPage {
  MenuPage({
    required this.name,
    String layout = 'list',
    MenuTree? tree,
    Map<String, Object?> metadata = const {},
  })  : assert(name.isNotEmpty, 'Menu pages must be named.'),
        tree = tree ?? MenuTree.fromMetadata(metadata['tree']),
        _metadata = Map<String, Object?>.unmodifiable({
          ...metadata,
          'layout': layout,
          'tree': (tree ?? MenuTree.fromMetadata(metadata['tree']))
              .toMetadata(),
        });

  @override
  final String name;

  @override
  String get type => 'menu';

  final Map<String, Object?> _metadata;

  @override
  Map<String, Object?> get metadata => _metadata;

  /// Structured metadata representing the navigational tree.
  final MenuTree tree;

  /// Current layout identifier stored in the metadata.
  String get layout => metadata['layout'] as String? ?? 'list';

  /// Returns a copy of the page with the provided metadata overrides.
  MenuPage copyWith({
    String? name,
    String? layout,
    MenuTree? tree,
    Map<String, Object?>? metadata,
  }) {
    final nextMetadata = Map<String, Object?>.from(_metadata);
    if (metadata != null) {
      nextMetadata.addAll(metadata);
    }
    if (layout != null) {
      nextMetadata['layout'] = layout;
    }
    MenuTree resolvedTree;
    if (tree != null) {
      resolvedTree = tree;
    } else if (metadata != null && metadata.containsKey('tree')) {
      resolvedTree = MenuTree.fromMetadata(nextMetadata['tree']);
    } else {
      resolvedTree = this.tree;
    }
    nextMetadata['tree'] = resolvedTree.toMetadata();
    return MenuPage(
      name: name ?? this.name,
      layout: nextMetadata['layout'] as String? ?? 'list',
      metadata: nextMetadata,
      tree: resolvedTree,
    );
  }
}
