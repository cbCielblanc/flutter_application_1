part of 'workbook_navigator.dart';

class CustomAction {
  CustomAction({
    required this.id,
    required this.label,
    required this.template,
  });

  final String id;
  final String label;
  final String template;
}

class _ScriptTreeNode {
  const _ScriptTreeNode({
    required this.id,
    required this.label,
    this.subtitle,
    this.icon,
    this.descriptor,
    this.pageName,
    this.rawSharedKey,
    this.hasContent = false,
    this.emptyLabel,
    this.isGroup = false,
    this.children = const <_ScriptTreeNode>[],
  });

  final String id;
  final String label;
  final String? subtitle;
  final IconData? icon;
  final ScriptDescriptor? descriptor;
  final String? pageName;
  final String? rawSharedKey;
  final bool hasContent;
  final String? emptyLabel;
  final bool isGroup;
  final List<_ScriptTreeNode> children;
}

class _ScriptTreeBuildResult {
  _ScriptTreeBuildResult({
    required this.nodes,
    required this.parents,
    required this.expandableIds,
  });

  final List<_ScriptTreeNode> nodes;
  final Map<String, String?> parents;
  final Set<String> expandableIds;
}

class ScriptEditorTab {
  ScriptEditorTab({
    required this.descriptor,
    required this.controller,
    this.pageName,
    this.rawSharedKey,
    this.isDirty = false,
    this.isMutable = true,
    this.status,
  });

  ScriptDescriptor descriptor;
  final CodeController controller;
  bool isDirty;
  bool isMutable;
  String? status;
  String? pageName;
  String? rawSharedKey;
  VoidCallback? listener;
}
