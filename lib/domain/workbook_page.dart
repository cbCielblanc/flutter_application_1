import 'package:meta/meta.dart';

/// Describes a page contained in a [Workbook].
///
/// Implementations are expected to provide a stable [type] identifier, a
/// user-facing [name] and a serialisable [metadata] map offering additional
/// information about the page.
@immutable
abstract class WorkbookPage {
  const WorkbookPage();

  /// Type identifier describing the page (e.g. `sheet`).
  String get type;

  /// Unique name of the page within its workbook.
  String get name;

  /// Serialisable metadata describing the page.
  Map<String, Object?> get metadata;
}
