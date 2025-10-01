import 'package:flutter/material.dart';

import '../domain/menu_page.dart';
import '../domain/notes_page.dart';
import '../domain/sheet.dart';
import '../domain/workbook_page.dart';

IconData workbookPageIcon(WorkbookPage page) {
  if (page is MenuPage) {
    return Icons.menu;
  }
  if (page is NotesPage) {
    return Icons.note_alt;
  }
  if (page is Sheet) {
    return Icons.grid_on;
  }
  return Icons.description;
}

String workbookPageDescription(WorkbookPage page) {
  if (page is MenuPage) {
    return 'Page de menu';
  }
  if (page is NotesPage) {
    return 'Page de notes';
  }
  if (page is Sheet) {
    return 'Feuille de calcul';
  }
  return 'Page personnalisée';
}
