import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/domain/menu_page.dart';
import 'package:flutter_application_1/domain/notes_page.dart';
import 'package:flutter_application_1/domain/sheet.dart';
import 'package:flutter_application_1/domain/workbook.dart';
import 'package:flutter_application_1/services/workbook_storage.dart';

void main() {
  group('WorkbookStorage', () {
    late Directory tempDir;
    late WorkbookStorage storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('workbook_storage_test');
      storage = WorkbookStorage(
        appSupportDirectoryProvider: () async => tempDir,
        fileName: 'test_workbook.json',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('returns null when no workbook has been saved yet', () async {
      final workbook = await storage.load();
      expect(workbook, isNull);
    });

    test('serialises and deserialises a workbook with sheets and notes', () async {
      final menu = MenuPage(name: 'Menu', layout: 'grid');
      final sheet = Sheet.fromRows(
        name: 'Données',
        rows: const [
          ['Produit', 'Quantité'],
          ['A', '10'],
          ['B', '5'],
        ],
      );
      final notes = NotesPage(
        name: 'Notes',
        content: 'Remarques importantes',
        metadata: const {
          'auteur': 'Testeur',
          'tags': ['urgent', 'finance'],
        },
      );
      final workbook = Workbook(pages: [menu, sheet, notes]);

      await storage.save(workbook);
      final file = File('${tempDir.path}/test_workbook.json');
      expect(await file.exists(), isTrue);

      final restored = await storage.load();
      expect(restored, isNotNull);
      final restoredWorkbook = restored!;
      expect(restoredWorkbook.pages.length, equals(3));

      final restoredMenu = restoredWorkbook.pages[0];
      expect(restoredMenu, isA<MenuPage>());
      expect((restoredMenu as MenuPage).layout, equals('grid'));

      final restoredSheet = restoredWorkbook.pages[1];
      expect(restoredSheet, isA<Sheet>());
      final sheetRows = (restoredSheet as Sheet).rows;
      expect(sheetRows.length, equals(3));
      expect(sheetRows[1][0].value, equals('A'));
      expect(sheetRows[2][1].value, equals('5'));

      final restoredNotes = restoredWorkbook.pages[2];
      expect(restoredNotes, isA<NotesPage>());
      final notesPage = restoredNotes as NotesPage;
      expect(notesPage.content, equals('Remarques importantes'));
      expect(notesPage.metadata['auteur'], equals('Testeur'));
      expect(notesPage.metadata['tags'], containsAll(['urgent', 'finance']));
    });
  });
}
