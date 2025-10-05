import 'package:flutter_application_1/application/commands/workbook_command_manager.dart';
import 'package:flutter_application_1/application/scripts/api/api.dart';
import 'package:flutter_application_1/domain/sheet.dart';
import 'package:flutter_application_1/domain/workbook.dart';
import 'package:flutter_test/flutter_test.dart';

WorkbookCommandManager _buildManager() {
  final sheet = Sheet.fromRows(
    name: 'Feuille 1',
    rows: const <List<Object?>>[
      <Object?>['Nom', 'Statut', 'Score'],
      <Object?>['Alice', '  actif ', '12.5'],
      <Object?>['Bob', 'inactif', '7.3'],
      <Object?>['Clara', 'actif', '9.4'],
    ],
  );
  final workbook = Workbook(pages: [sheet]);
  return WorkbookCommandManager(initialWorkbook: workbook);
}

void main() {
  group('SheetApi range wrappers', () {
    test('range returns values and supports chained mutations', () {
      final manager = _buildManager();
      final sheet = ScriptApi(commandManager: manager).workbook.activeSheet!;

      final range = sheet.range('A2:C4');
      expect(range, isNotNull);
      expect(range!.values.length, equals(3));
      expect(range.values.first.first, equals('Alice'));

      range
          .setValues(const [
            <Object?>['Alice', 'actif', 14],
            <Object?>['Bob', 'inactif', 7],
            <Object?>['Clara', 'actif', 9],
          ])
          .formatAsNumber(null)
          .sortByColumn(2, false)
          .autoFit();

      final updated = manager.workbook.sheets.first;
      expect(updated.rows[0][2].value, equals('Score'));
      expect(updated.rows[1][2].value, equals(9));
      expect(updated.rows[2][1].value, equals('inactif'));
      expect(updated.rows[1][1].value, equals('actif'));
      expect(range.lastResult, isTrue);
    });

    test('fillDown copies top values to lower rows', () {
      final manager = _buildManager();
      final sheet = ScriptApi(commandManager: manager).workbook.activeSheet!;
      final range = sheet.range('B2:B4');
      expect(range, isNotNull);

      range!.fillDown();

      final updated = manager.workbook.sheets.first;
      expect(updated.rows[1][1].value, equals('  actif '));
      expect(updated.rows[2][1].value, equals('  actif '));
      expect(updated.rows[3][1].value, equals('  actif '));
    });
  });

  group('RowApi and ColumnApi helpers', () {
    test('row allows inline updates and formatting', () {
      final manager = _buildManager();
      final sheet = ScriptApi(commandManager: manager).workbook.activeSheet!;

      final row = sheet.row(1);
      expect(row, isNotNull);
      row!
          .setValues(const <Object?>['Alice', 'active', '10.0'])
          .formatAsNumber(null)
          .autoFit();

      final updated = manager.workbook.sheets.first;
      expect(updated.rows[1][2].value, equals(10));
      expect(updated.rows[1][1].value, equals('active'));
      expect(row.lastResult, isTrue);
    });

    test('column supports fillDown and numeric formatting', () {
      final manager = _buildManager();
      final sheet = ScriptApi(commandManager: manager).workbook.activeSheet!;
      final column = sheet.column(2);
      expect(column, isNotNull);
      column!
          .setValues(const <Object?>['Score', '1.4', '2.6', '3.9'])
          .formatAsNumber(1)
          .fillDown();

      final updated = manager.workbook.sheets.first;
      expect(updated.rows[1][2].value, equals(1.4));
      expect(updated.rows[2][2].value, equals(1.4));
      expect(updated.rows[3][2].value, equals(1.4));
    });

    test('row/column return null when out of bounds', () {
      final manager = _buildManager();
      final sheet = ScriptApi(commandManager: manager).workbook.activeSheet!;
      expect(sheet.row(-1), isNull);
      expect(sheet.column(10), isNull);
    });
  });

  group('ChartApi', () {
    test('describe exposes source metadata', () {
      final manager = _buildManager();
      final sheet = ScriptApi(commandManager: manager).workbook.activeSheet!;
      final chart = sheet.chart('A1:C4');
      expect(chart, isNotNull);

      final description = chart!.describe();
      expect(description['sheet'], equals('Feuille 1'));
      expect(description['startRow'], equals(0));
      expect(description['endColumn'], equals(2));

      chart.updateRange(sheet.range('A2:C4')!);
      final next = chart.describe();
      expect(next['startRow'], equals(1));
    });
  });
}
