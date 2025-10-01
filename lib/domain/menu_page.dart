import 'package:meta/meta.dart';

import 'workbook_page.dart';

/// Represents a navigational menu page in the workbook.
@immutable
class MenuPage extends WorkbookPage {
  MenuPage({
    required this.name,
    String layout = 'list',
    Map<String, Object?> metadata = const {},
  })  : assert(name.isNotEmpty, 'Menu pages must be named.'),
        _metadata = Map<String, Object?>.unmodifiable({
          ...metadata,
          'layout': layout,
        });

  @override
  final String name;

  @override
  String get type => 'menu';

  final Map<String, Object?> _metadata;

  @override
  Map<String, Object?> get metadata => _metadata;

  /// Current layout identifier stored in the metadata.
  String get layout => metadata['layout'] as String? ?? 'list';

  /// Returns a copy of the page with the provided metadata overrides.
  MenuPage copyWith({
    String? name,
    String? layout,
    Map<String, Object?>? metadata,
  }) {
    final nextMetadata = Map<String, Object?>.from(_metadata);
    if (metadata != null) {
      nextMetadata.addAll(metadata);
    }
    if (layout != null) {
      nextMetadata['layout'] = layout;
    }
    return MenuPage(
      name: name ?? this.name,
      layout: nextMetadata['layout'] as String? ?? 'list',
      metadata: nextMetadata,
    );
  }
}
