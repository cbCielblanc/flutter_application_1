import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/domain/cell.dart';
import 'package:flutter_application_1/domain/sheet.dart';
import 'package:flutter_application_1/domain/workbook.dart';
import 'package:flutter_application_1/services/csv_service.dart';

void main() {
  group('CsvService', () {
    late Directory tempDir;
    late CsvService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('csv_service_test');
      service = const CsvService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('loadFromCsv parses values with custom delimiter', () async {
      final file = File('${tempDir.path}/people.csv');
      await file.writeAsString('Name;Age;Active\nAlice;42;TRUE\nBob;27;FALSE');

      final workbook = await service.loadFromCsv(
        file: file,
        sheetName: 'People',
        fieldDelimiter: ';',
      );

      final sheet = workbook.sheets.single;
      expect(sheet.name, 'People');
      expect(sheet.rowCount, 3);
      expect(sheet.columnCount, 3);

      final rows = sheet.rows;
      expect(rows[1][1].type, CellType.number);
      expect(rows[1][1].value, 42);
      expect(rows[1][2].type, CellType.boolean);
      expect(rows[1][2].value, true);
      expect(rows[2][2].value, false);
    });

    test('saveToCsv persists typed cells using the delimiter', () async {
      final workbook = Workbook(
        sheets: [
          Sheet.fromRows(
            name: 'Notes',
            rows: [
              ['Name', 'Comment'],
              ['Alice', 'Hello, world'],
              ['Bob', 'Says "Hi"'],
            ],
          ),
        ],
      );

      final file = File('${tempDir.path}/notes.csv');
      await service.saveToCsv(
        workbook: workbook,
        file: file,
        fieldDelimiter: ';',
      );

      final contents = await file.readAsString();
      final parsed = const CsvToListConverter(shouldParseNumbers: false)
          .convert(contents, fieldDelimiter: ';');

      expect(parsed.length, 3);
      expect(parsed[1][1], 'Hello, world');
      expect(parsed[2][1], 'Says "Hi"');
    });

    test('loadFromCsv throws when delimiters are inconsistent', () async {
      final file = File('${tempDir.path}/broken.csv');
      await file.writeAsString('A,B\n1;2');

      expect(
        () => service.loadFromCsv(file: file),
        throwsA(isA<FormatException>()),
      );
    });

    test('loadFromCsv propagates malformed quotes', () async {
      final file = File('${tempDir.path}/quote.csv');
      await file.writeAsString('Name,Quote\nAlice,"Hello');

      expect(
        () => service.loadFromCsv(file: file),
        throwsA(isA<FormatException>()),
      );
    });

    test('loadFromCsv rejects rows with variable lengths', () async {
      final file = File('${tempDir.path}/variable.csv');
      await file.writeAsString('A,B\n1,2\n3');

      expect(
        () => service.loadFromCsv(file: file),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
