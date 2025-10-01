import 'package:meta/meta.dart';

import 'workbook_page.dart';

/// Represents a free-form note page stored in the workbook.
@immutable
class NotesPage extends WorkbookPage {
  NotesPage({
    required this.name,
    String? content,
    Map<String, Object?> metadata = const {},
  })  : _metadata = Map<String, Object?>.unmodifiable({
          ...metadata,
          if (content != null) 'content': content,
        }),
        _content = content ?? (metadata['content'] as String?) ?? '';

  @override
  final String name;

  @override
  String get type => 'notes';

  final String _content;
  final Map<String, Object?> _metadata;

  /// Raw text content of the notes page.
  String get content => _content;

  @override
  Map<String, Object?> get metadata => _metadata;

  NotesPage copyWith({
    String? name,
    String? content,
    Map<String, Object?>? metadata,
  }) {
    final nextMetadata = Map<String, Object?>.from(_metadata);
    if (metadata != null) {
      nextMetadata.addAll(metadata);
    }
    if (content != null) {
      nextMetadata['content'] = content;
    }
    return NotesPage(
      name: name ?? this.name,
      content: nextMetadata['content'] as String? ?? '',
      metadata: nextMetadata,
    );
  }
}
