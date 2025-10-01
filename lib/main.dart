import 'package:flutter/material.dart';

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
  final List<String> _sheets = ['Feuille 1'];
  int _selectedSheetIndex = 0;
  int _nextSheetNumber = 2;

  void _handleSelectSheet(int index) {
    setState(() {
      _selectedSheetIndex = index;
    });
  }

  void _handleAddSheet() {
    setState(() {
      _sheets.add('Feuille $_nextSheetNumber');
      _nextSheetNumber += 1;
      _selectedSheetIndex = _sheets.length - 1;
    });
  }

  void _handleRemoveSheet(int index) {
    if (_sheets.length == 1) {
      return;
    }
    setState(() {
      _sheets.removeAt(index);
      if (_selectedSheetIndex >= _sheets.length) {
        _selectedSheetIndex = _sheets.length - 1;
      }
    });
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
          sheets: List.unmodifiable(_sheets),
          selectedSheetIndex: _selectedSheetIndex,
          onSheetSelected: _handleSelectSheet,
          onAddSheet: _handleAddSheet,
          onRemoveSheet: _handleRemoveSheet,
        ),
      ),
    );
  }
}
