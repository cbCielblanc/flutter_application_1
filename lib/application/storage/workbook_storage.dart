import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../domain/cell.dart';
import '../../domain/menu_page.dart';
import '../../domain/notes_page.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import '../../domain/workbook_page.dart';

class WorkbookStorage {
  WorkbookStorage({Directory? directory}) : _directoryOverride = directory;

  final Directory? _directoryOverride;

  Directory? _writeDirectory;

  bool get isAvailable => !kIsWeb;

  Future<Workbook?> load() async {
    try {
      final file = await _storageFile();
      if (file == null || !await file.exists()) {
        return null;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return null;
      }
      final data = jsonDecode(raw);
      if (data is! Map<String, Object?>) {
        throw const FormatException('Unexpected workbook payload.');
      }
      return _WorkbookSerialiser.fromJson(data);
    } catch (error, stackTrace) {
      debugPrint('Failed to load workbook: $error\n$stackTrace');
      return null;
    }
  }

  Future<bool> save(Workbook workbook) async {
    try {
      final file = await _storageFile();
      if (file == null) {
        return false;
      }
      final encoded = const JsonEncoder.withIndent(
        '  ',
      ).convert(_WorkbookSerialiser.toJson(workbook));
      await file.writeAsString(encoded);
      return true;
    } catch (error, stackTrace) {
      debugPrint('Failed to save workbook: $error\n$stackTrace');
      return false;
    }
  }

  Future<File?> _storageFile() async {
    final directory = await _ensureWriteDirectory();
    if (directory == null) {
      return null;
    }
    return File(path.join(directory.path, 'workbook.json'));
  }

  Future<Directory?> _ensureWriteDirectory() async {
    if (kIsWeb) {
      return null;
    }
    if (_writeDirectory != null) {
      return _writeDirectory;
    }
    if (_directoryOverride != null) {
      if (!await _directoryOverride!.exists()) {
        await _directoryOverride!.create(recursive: true);
      }
      _writeDirectory = _directoryOverride;
      return _writeDirectory;
    }
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final directory = Directory(path.join(supportDirectory.path, 'workbook'));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      _writeDirectory = directory;
      return _writeDirectory;
    } catch (_) {
      return null;
    }
  }
}

class _WorkbookSerialiser {
  static Map<String, Object?> toJson(Workbook workbook) {
    return {'version': 1, 'pages': workbook.pages.map(_pageToJson).toList()};
  }

  static Workbook fromJson(Map<String, Object?> json) {
    final pagesData = json['pages'];
    if (pagesData is! List) {
      throw const FormatException('Workbook payload must contain pages.');
    }
    final pages = <WorkbookPage>[];
    for (var index = 0; index < pagesData.length; index++) {
      final entry = pagesData[index];
      final page = _pageFromJson(entry);
      if (page != null) {
        pages.add(page);
      } else {
        debugPrint('Skipping unknown workbook page at index $index.');
      }
    }
    if (pages.isEmpty) {
      throw const FormatException('Workbook payload contained no pages.');
    }
    return Workbook(pages: pages);
  }

  static Map<String, Object?> _pageToJson(WorkbookPage page) {
    if (page is Sheet) {
      return {
        'type': 'sheet',
        'name': page.name,
        'rows': page.rows
            .map(
              (row) => row
                  .map((cell) => {'type': cell.type.name, 'value': cell.value})
                  .toList(growable: false),
            )
            .toList(growable: false),
      };
    }
    if (page is NotesPage) {
      return {
        'type': 'notes',
        'name': page.name,
        'content': page.content,
        if (page.metadata.isNotEmpty)
          'metadata': Map<String, Object?>.from(page.metadata),
      };
    }
    if (page is MenuPage) {
      return {
        'type': 'menu',
        'name': page.name,
        if (page.metadata.isNotEmpty)
          'metadata': Map<String, Object?>.from(page.metadata),
      };
    }
    return {
      'type': page.type,
      'name': page.name,
      if (page.metadata.isNotEmpty)
        'metadata': Map<String, Object?>.from(page.metadata),
    };
  }

  static WorkbookPage? _pageFromJson(Object? data) {
    if (data is! Map<String, Object?>) {
      debugPrint('Invalid workbook page payload: $data');
      return null;
    }
    final type = data['type']?.toString();
    final name = data['name']?.toString();
    if (type == null || name == null || name.isEmpty) {
      debugPrint('Workbook page is missing type or name: $data');
      return null;
    }
    switch (type) {
      case 'sheet':
        final rowsData = data['rows'];
        if (rowsData is! List) {
          debugPrint('Sheet payload is missing rows: $data');
          return null;
        }
        final rows = <List<Cell>>[];
        for (var r = 0; r < rowsData.length; r++) {
          final rowData = rowsData[r];
          if (rowData is! List) {
            debugPrint('Row payload is invalid: $rowData');
            return null;
          }
          final cells = <Cell>[];
          for (var c = 0; c < rowData.length; c++) {
            final cellData = rowData[c];
            cells.add(_deserializeCell(r, c, cellData));
          }
          rows.add(List<Cell>.unmodifiable(cells));
        }
        if (rows.isEmpty) {
          debugPrint('Sheet payload contains no rows: $data');
          return null;
        }
        return Sheet(name: name, rows: rows);
      case 'notes':
        final metadata = _extractMetadata(data['metadata']);
        final content = data['content']?.toString();
        return NotesPage(name: name, content: content, metadata: metadata);
      case 'menu':
        final metadata = _extractMetadata(data['metadata']);
        return MenuPage(name: name, metadata: metadata);
      default:
        final metadata = _extractMetadata(data['metadata']);
        return _FallbackWorkbookPage(
          type: type,
          name: name,
          metadata: metadata,
        );
    }
  }

  static Cell _deserializeCell(int row, int column, Object? value) {
    if (value is Map<String, Object?>) {
      final typeName = value['type']?.toString();
      final rawValue = value.containsKey('value') ? value['value'] : null;
      final type = _parseCellType(typeName);
      return Cell(
        row: row,
        column: column,
        type: type,
        value: _coerceCellValue(type, rawValue),
      );
    }
    return Cell.fromValue(row: row, column: column, value: value);
  }

  static CellType _parseCellType(String? type) {
    if (type == null) {
      return CellType.empty;
    }
    for (final candidate in CellType.values) {
      if (candidate.name == type) {
        return candidate;
      }
    }
    return CellType.empty;
  }

  static Object? _coerceCellValue(CellType type, Object? rawValue) {
    switch (type) {
      case CellType.empty:
        return null;
      case CellType.boolean:
        if (rawValue is bool) {
          return rawValue;
        }
        if (rawValue is String) {
          return rawValue.toLowerCase() == 'true';
        }
        return rawValue == null ? null : rawValue == 1;
      case CellType.number:
        if (rawValue is num) {
          return rawValue;
        }
        if (rawValue is String) {
          return num.tryParse(rawValue);
        }
        return null;
      case CellType.text:
        if (rawValue == null) {
          return '';
        }
        return rawValue.toString();
    }
  }

  static Map<String, Object?> _extractMetadata(Object? payload) {
    if (payload is Map<String, Object?>) {
      return Map<String, Object?>.from(payload);
    }
    return <String, Object?>{};
  }
}

class _FallbackWorkbookPage extends WorkbookPage {
  _FallbackWorkbookPage({
    required this.type,
    required this.name,
    Map<String, Object?> metadata = const {},
  }) : _metadata = Map<String, Object?>.unmodifiable(metadata);

  @override
  final String type;

  @override
  final String name;

  final Map<String, Object?> _metadata;

  @override
  Map<String, Object?> get metadata => _metadata;
}
