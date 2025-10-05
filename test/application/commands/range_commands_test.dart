import 'package:flutter_application_1/application/commands/auto_fill_range_command.dart';
import 'package:flutter_application_1/application/commands/auto_fit_range_command.dart';
import 'package:flutter_application_1/application/commands/format_range_as_number_command.dart';
import 'package:flutter_application_1/application/commands/set_range_values_command.dart';
import 'package:flutter_application_1/application/commands/sort_range_command.dart';
import 'package:flutter_application_1/application/commands/workbook_command.dart';
import 'package:flutter_application_1/domain/sheet.dart';
import 'package:flutter_application_1/domain/workbook.dart';
import 'package:flutter_test/flutter_test.dart';

WorkbookCommandContext _buildContext(Sheet sheet) {
  final workbook = Workbook(pages: [sheet]);
  return WorkbookCommandContext(workbook: workbook, activePageIndex: 0);
}

Sheet _applyCommand(WorkbookCommand command, Sheet sheet) {
  final context = _buildContext(sheet);
  final result = command.execute(context);
  expect(result.workbook.pages, hasLength(1));
  expect(result.workbook.pages.first, isA<Sheet>());
  return result.workbook.pages.first as Sheet;
}

void main() {
  group('SetRangeValuesCommand', () {
    test('applies values to the requested range', () {
      final sheet = Sheet.fromRows(
        name: 'Feuille 1',
        rows: const <List<Object?>>[
          <Object?>['A', 'B', 'C'],
          <Object?>['D', 'E', 'F'],
        ],
      );
      final command = SetRangeValuesCommand(
        sheetName: sheet.name,
        startRow: 0,
        startColumn: 1,
        values: const [
          <Object?>['X', 'Y'],
          <Object?>['Z', 'W'],
        ],
      );

      final updated = _applyCommand(command, sheet);
      expect(updated.rows[0][1].value, equals('X'));
      expect(updated.rows[0][2].value, equals('Y'));
      expect(updated.rows[1][1].value, equals('Z'));
      expect(updated.rows[1][2].value, equals('W'));
    });
  });

  group('AutoFillRangeCommand', () {
    test('fills values downward from the first row', () {
      final sheet = Sheet.fromRows(
        name: 'Feuille 1',
        rows: const <List<Object?>>[
          <Object?>['src', 1],
          <Object?>['', 0],
          <Object?>['', 0],
        ],
      );
      final command = AutoFillRangeCommand(
        sheetName: sheet.name,
        startRow: 0,
        startColumn: 0,
        rowCount: 3,
        columnCount: 1,
        direction: RangeFillDirection.down,
      );

      final updated = _applyCommand(command, sheet);
      expect(updated.rows[1][0].value, equals('src'));
      expect(updated.rows[2][0].value, equals('src'));
    });

    test('fills values to the right from the first column', () {
      final sheet = Sheet.fromRows(
        name: 'Feuille 1',
        rows: const <List<Object?>>[
          <Object?>['seed', '', ''],
        ],
      );
      final command = AutoFillRangeCommand(
        sheetName: sheet.name,
        startRow: 0,
        startColumn: 0,
        rowCount: 1,
        columnCount: 3,
        direction: RangeFillDirection.right,
      );

      final updated = _applyCommand(command, sheet);
      expect(updated.rows[0][1].value, equals('seed'));
      expect(updated.rows[0][2].value, equals('seed'));
    });
  });

  group('SortRangeCommand', () {
    test('sorts rows by the provided column', () {
      final sheet = Sheet.fromRows(
        name: 'Feuille 1',
        rows: const <List<Object?>>[
          <Object?>['B', 2],
          <Object?>['C', 3],
          <Object?>['A', 1],
        ],
      );
      final command = SortRangeCommand(
        sheetName: sheet.name,
        startRow: 0,
        startColumn: 0,
        rowCount: 3,
        columnCount: 2,
        columnOffset: 1,
        ascending: false,
      );

      final updated = _applyCommand(command, sheet);
      expect(updated.rows[0][0].value, equals('C'));
      expect(updated.rows[1][0].value, equals('B'));
      expect(updated.rows[2][0].value, equals('A'));
    });
  });

  group('FormatRangeAsNumberCommand', () {
    test('parses numeric strings and applies rounding', () {
      final sheet = Sheet.fromRows(
        name: 'Feuille 1',
        rows: const <List<Object?>>[
          <Object?>['12.345', 'invalid'],
        ],
      );
      final command = FormatRangeAsNumberCommand(
        sheetName: sheet.name,
        startRow: 0,
        startColumn: 0,
        rowCount: 1,
        columnCount: 2,
        decimalDigits: 2,
      );

      final updated = _applyCommand(command, sheet);
      expect(updated.rows[0][0].value, equals(12.35));
      expect(updated.rows[0][1].value, equals('invalid'));
    });
  });

  group('AutoFitRangeCommand', () {
    test('trims surrounding whitespace for text values', () {
      final sheet = Sheet.fromRows(
        name: 'Feuille 1',
        rows: const <List<Object?>>[
          <Object?>['  spaced  ', ' ok '],
        ],
      );
      final command = AutoFitRangeCommand(
        sheetName: sheet.name,
        startRow: 0,
        startColumn: 0,
        rowCount: 1,
        columnCount: 2,
      );

      final updated = _applyCommand(command, sheet);
      expect(updated.rows[0][0].value, equals('spaced'));
      expect(updated.rows[0][1].value, equals('ok'));
    });
  });
}
