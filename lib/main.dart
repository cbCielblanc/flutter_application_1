import 'package:flutter/material.dart';

import 'application/commands/workbook_command_manager.dart';
import 'domain/cell.dart';
import 'domain/menu_page.dart';
import 'domain/sheet.dart';
import 'domain/workbook.dart';
import 'presentation/workbook_navigator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final WorkbookCommandManager _commandManager;

  @override
  void initState() {
    super.initState();
    _commandManager = WorkbookCommandManager(
      initialWorkbook: _createInitialWorkbook(),
    );
  }

  @override
  void dispose() {
    _commandManager.dispose();
    super.dispose();
  }

  Workbook _createInitialWorkbook() {
    const rowCount = 20;
    const columnCount = 8;
    final rows = List<List<Cell>>.generate(
      rowCount,
      (row) => List<Cell>.generate(
        columnCount,
        (column) =>
            Cell(row: row, column: column, type: CellType.empty, value: null),
      ),
      growable: false,
    );
    final sheet = Sheet(name: 'Feuille 1', rows: rows);
    final menu = MenuPage(name: 'Menu principal');
    return Workbook(pages: [menu, sheet]);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Classeur'),
        ),
        body: WorkbookNavigator(
          commandManager: _commandManager,
        ),
      ),
    );
  }
}
