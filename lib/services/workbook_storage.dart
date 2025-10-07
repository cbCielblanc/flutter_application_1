import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../domain/menu_page.dart';
import '../domain/notes_page.dart';
import '../domain/sheet.dart';
import '../domain/workbook.dart';
import '../domain/workbook_page.dart';

typedef _DirectoryProvider = Future<Directory> Function();

/// Persists [Workbook] instances to the local file system.
class WorkbookStorage {
  WorkbookStorage({
    _DirectoryProvider? appSupportDirectoryProvider,
    String fileName = 'workbook.json',
  })  : _getSupportDirectory =
            appSupportDirectoryProvider ?? getApplicationSupportDirectory,
        _fileName = fileName;

  final _DirectoryProvider _getSupportDirectory;
  final String _fileName;
  File? _cachedFile;

  /// Loads the previously saved workbook or `null` if none exists.
  Future<Workbook?> load() async {
    final file = await _resolveFile(createDirectory: false);
    if (!await file.exists()) {
      return null;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return null;
    }

    final data = jsonDecode(raw);
    if (data is! Map<String, Object?>) {
      throw const FormatException('Invalid workbook structure.');
    }

    final pagesData = data['pages'];
    if (pagesData is! List) {
      throw const FormatException('Invalid workbook pages payload.');
    }

    final pages = <WorkbookPage>[];
    for (final entry in pagesData) {
      final page = _decodePage(entry);
      if (page != null) {
        pages.add(page);
      }
    }

    if (pages.isEmpty) {
      return null;
    }

    return Workbook(pages: pages);
  }

  /// Persists the provided [workbook].
  Future<void> save(Workbook workbook) async {
    final file = await _resolveFile(createDirectory: true);
    final encodedPages = workbook.pages.map(_encodePage).toList();
    final payload = {'pages': encodedPages};
    final encoder = const JsonEncoder.withIndent('  ');
    final json = encoder.convert(payload);
    await file.writeAsString(json, flush: true);
  }

  WorkbookPage? _decodePage(Object? entry) {
    if (entry is! Map<String, Object?>) {
      throw const FormatException('Invalid page entry.');
    }
    final type = entry['type']?.toString();
    final name = entry['name']?.toString();
    if (type == null || name == null) {
      throw const FormatException('Page entries must contain type and name.');
    }

    switch (type) {
      case 'sheet':
        final csv = entry['csv']?.toString();
        if (csv == null) {
          throw const FormatException('Sheet entries must include CSV data.');
        }
        return Sheet.fromCsv(name: name, csv: csv);
      case 'notes':
        final metadata = _decodeMap(entry['metadata']);
        final content = entry['content']?.toString() ??
            metadata['content']?.toString() ??
            '';
        return NotesPage(name: name, content: content, metadata: metadata);
      case 'menu':
        final metadata = _decodeMap(entry['metadata']);
        final layout = entry['layout']?.toString();
        return MenuPage(
          name: name,
          layout: layout ?? metadata['layout']?.toString() ?? 'list',
          metadata: metadata,
        );
      default:
        throw FormatException('Unsupported page type: $type');
    }
  }

  Map<String, Object?> _encodePage(WorkbookPage page) {
    if (page is Sheet) {
      return {
        'type': page.type,
        'name': page.name,
        'csv': page.toCsv(),
        'metadata': page.metadata,
      };
    }
    if (page is NotesPage) {
      return {
        'type': page.type,
        'name': page.name,
        'content': page.content,
        'metadata': page.metadata,
      };
    }
    if (page is MenuPage) {
      return {
        'type': page.type,
        'name': page.name,
        'layout': page.layout,
        'metadata': page.metadata,
      };
    }
    throw FormatException('Unsupported page type: ${page.type}');
  }

  Future<File> _resolveFile({required bool createDirectory}) async {
    if (_cachedFile != null) {
      return _cachedFile!;
    }
    final directory = await _getSupportDirectory();
    if (createDirectory && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File(p.join(directory.path, _fileName));
    _cachedFile = file;
    return file;
  }

  Map<String, Object?> _decodeMap(Object? value) {
    if (value is Map) {
      return value.map((key, dynamic v) => MapEntry(key.toString(), v));
    }
    return <String, Object?>{};
  }
}
