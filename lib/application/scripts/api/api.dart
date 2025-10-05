import '../../commands/auto_fill_range_command.dart';
import '../../commands/auto_fit_range_command.dart';
import '../../commands/clear_sheet_command.dart';
import '../../commands/format_range_as_number_command.dart';
import '../../commands/insert_column_command.dart';
import '../../commands/insert_row_command.dart';
import '../../commands/set_cell_value_command.dart';
import '../../commands/set_range_values_command.dart';
import '../../commands/sort_range_command.dart';
import '../../commands/workbook_command_manager.dart';
import '../../../domain/cell.dart';
import '../../../domain/sheet.dart';
import '../../../domain/workbook.dart';
import '../../../state/sheet_selection_state.dart';

/// Point d'accès racine vers les APIs scripts.
class ScriptApi {
  ScriptApi({required WorkbookCommandManager commandManager})
      : _commandManager = commandManager;

  final WorkbookCommandManager _commandManager;

  /// Fournit un accès au classeur courant.
  WorkbookApi get workbook => WorkbookApi._(_commandManager);
}

/// Wrapper sécurisé autour d'un [Workbook].
class WorkbookApi {
  WorkbookApi._(this._commandManager);

  final WorkbookCommandManager _commandManager;

  Workbook get _workbook => _commandManager.workbook;

  /// Renvoie les noms des feuilles disponibles.
  List<String> get sheetNames =>
      _workbook.sheets.map((sheet) => sheet.name).toList(growable: false);

  /// Renvoie l'index de la feuille active ou `-1` lorsqu'aucune feuille n'est active.
  int get activeSheetIndex => _commandManager.activeSheetIndex;

  /// Accès à la feuille active.
  SheetApi? get activeSheet {
    final index = activeSheetIndex;
    if (index < 0) {
      return null;
    }
    final sheets = _workbook.sheets;
    if (index >= sheets.length) {
      return null;
    }
    return SheetApi._(_commandManager, sheets[index].name);
  }

  /// Retourne une feuille par son nom.
  SheetApi? sheetByName(String name) {
    for (final sheet in _workbook.sheets) {
      if (sheet.name == name) {
        return SheetApi._(_commandManager, sheet.name);
      }
    }
    return null;
  }

  /// Retourne une feuille par son index.
  SheetApi? sheetAt(int index) {
    final sheets = _workbook.sheets;
    if (index < 0 || index >= sheets.length) {
      return null;
    }
    final sheet = sheets[index];
    return SheetApi._(_commandManager, sheet.name);
  }

  /// Active une feuille via son nom.
  bool activateSheetByName(String name) {
    final sheets = _workbook.sheets;
    for (var i = 0; i < sheets.length; i++) {
      if (sheets[i].name == name) {
        _commandManager.setActiveSheet(i);
        return true;
      }
    }
    return false;
  }

  /// Active une feuille via son index.
  bool activateSheetAt(int index) {
    if (index < 0 || index >= _workbook.sheets.length) {
      return false;
    }
    _commandManager.setActiveSheet(index);
    return true;
  }

  /// Renvoie un instantané du classeur.
  Workbook snapshot() => _commandManager.workbook;
}

/// Wrapper sécurisé pour manipuler une feuille.
class SheetApi {
  SheetApi._(this._commandManager, this._sheetName);

  final WorkbookCommandManager _commandManager;
  final String _sheetName;

  Workbook get _workbook => _commandManager.workbook;

  Sheet _resolveSheet() {
    for (final sheet in _workbook.sheets) {
      if (sheet.name == _sheetName) {
        return sheet;
      }
    }
    throw StateError('Feuille introuvable : $_sheetName');
  }

  int? _resolvePageIndex() {
    for (final sheet in _workbook.sheets) {
      if (sheet.name == _sheetName) {
        final index = _workbook.pages.indexOf(sheet);
        return index == -1 ? null : index;
      }
    }
    return null;
  }

  String get name => _resolveSheet().name;

  int get rowCount => _resolveSheet().rowCount;

  int get columnCount => _resolveSheet().columnCount;

  /// Active la feuille dans le gestionnaire.
  bool activate() {
    final pageIndex = _resolvePageIndex();
    if (pageIndex == null) {
      return false;
    }
    _commandManager.setActivePage(pageIndex);
    return true;
  }

  /// Retourne un wrapper sur une cellule via ses coordonnées.
  CellApi cellAt(int row, int column) {
    final sheet = _resolveSheet();
    if (row < 0 || row >= sheet.rowCount) {
      throw RangeError.range(row, 0, sheet.rowCount - 1, 'row');
    }
    if (column < 0 || column >= sheet.columnCount) {
      throw RangeError.range(column, 0, sheet.columnCount - 1, 'column');
    }
    return CellApi._(
      commandManager: _commandManager,
      sheetName: sheet.name,
      row: row,
      column: column,
    );
  }

  /// Retourne un wrapper via une référence de type Excel (A1, B2, ...).
  CellApi? cellByLabel(String label) {
    final position = CellPosition.tryParse(label);
    if (position == null) {
      return null;
    }
    final sheet = _resolveSheet();
    if (position.row < 0 || position.row >= sheet.rowCount) {
      return null;
    }
    if (position.column < 0 || position.column >= sheet.columnCount) {
      return null;
    }
    return CellApi._(
      commandManager: _commandManager,
      sheetName: sheet.name,
      row: position.row,
      column: position.column,
    );
  }

  /// Insère une ligne à l'index souhaité (ou à la fin par défaut).
  bool insertRow([int? index]) {
    return _withActiveSheet(() {
      return _commandManager.execute(InsertRowCommand(rowIndex: index));
    });
  }

  /// Insère une colonne à l'index souhaité (ou à la fin par défaut).
  bool insertColumn([int? index]) {
    return _withActiveSheet(() {
      return _commandManager.execute(InsertColumnCommand(columnIndex: index));
    });
  }

  /// Efface l'intégralité de la feuille.
  bool clear() {
    return _withActiveSheet(() {
      return _commandManager.execute(ClearSheetCommand());
    });
  }

  /// Retourne un wrapper sur une plage rectangulaire.
  RangeApi? range(String reference) {
    final sheet = _resolveSheet();
    final coordinates = _RangeReferenceParser(sheet).parse(reference);
    if (coordinates == null) {
      return null;
    }
    return RangeApi._(
      commandManager: _commandManager,
      sheetName: sheet.name,
      coordinates: coordinates,
    );
  }

  /// Retourne un wrapper sur une ligne (index 0-based).
  RowApi? row(int index) {
    final sheet = _resolveSheet();
    if (index < 0 || index >= sheet.rowCount) {
      return null;
    }
    final coordinates = RangeCoordinates(
      startRow: index,
      endRow: index,
      startColumn: 0,
      endColumn: sheet.columnCount - 1,
    );
    return RowApi._(
      commandManager: _commandManager,
      sheetName: sheet.name,
      coordinates: coordinates,
    );
  }

  /// Retourne un wrapper sur une colonne (index 0-based).
  ColumnApi? column(int index) {
    final sheet = _resolveSheet();
    if (index < 0 || index >= sheet.columnCount) {
      return null;
    }
    final coordinates = RangeCoordinates(
      startRow: 0,
      endRow: sheet.rowCount - 1,
      startColumn: index,
      endColumn: index,
    );
    return ColumnApi._(
      commandManager: _commandManager,
      sheetName: sheet.name,
      coordinates: coordinates,
    );
  }

  /// Prépare un wrapper chart simple basé sur une plage.
  ChartApi? chart(String reference) {
    final rangeApi = range(reference);
    if (rangeApi == null) {
      return null;
    }
    return ChartApi._(rangeApi);
  }

  bool _withActiveSheet(bool Function() action) {
    final pageIndex = _resolvePageIndex();
    if (pageIndex == null) {
      return false;
    }
    final previousPageIndex = _commandManager.activePageIndex;
    final shouldSwitch = previousPageIndex != pageIndex;
    if (shouldSwitch) {
      _commandManager.setActivePage(pageIndex);
    }
    try {
      return action();
    } finally {
      if (shouldSwitch) {
        _commandManager.setActivePage(previousPageIndex);
      }
    }
  }
}

/// Wrapper autour d'une cellule spécifique.
class CellApi {
  CellApi._({
    required WorkbookCommandManager commandManager,
    required this.sheetName,
    required this.row,
    required this.column,
  }) : _commandManager = commandManager;

  final WorkbookCommandManager _commandManager;

  /// Nom de la feuille à laquelle appartient la cellule.
  final String sheetName;

  /// Index de ligne (base zéro).
  final int row;

  /// Index de colonne (base zéro).
  final int column;

  Sheet _resolveSheet() {
    final workbook = _commandManager.workbook;
    for (final sheet in workbook.sheets) {
      if (sheet.name == sheetName) {
        return sheet;
      }
    }
    throw StateError('Feuille introuvable : $sheetName');
  }

  Cell _resolveCell() {
    final sheet = _resolveSheet();
    if (row < 0 || row >= sheet.rowCount) {
      throw RangeError.range(row, 0, sheet.rowCount - 1, 'row');
    }
    if (column < 0 || column >= sheet.columnCount) {
      throw RangeError.range(column, 0, sheet.columnCount - 1, 'column');
    }
    return sheet.rows[row][column];
  }

  /// Libellé de type Excel (A1, B2, ...).
  String get label => CellPosition(row, column).label;

  /// Retourne la valeur brute de la cellule.
  Object? get value => _resolveCell().value;

  /// Retourne le type de la cellule.
  String get type => _resolveCell().type.name;

  /// Indique si la cellule est vide.
  bool get isEmpty => _resolveCell().type == CellType.empty;

  /// Valeur textuelle facilitant l'affichage.
  String get text => value?.toString() ?? '';

  /// Applique une nouvelle valeur à la cellule.
  bool setValue(Object? newValue) {
    final workbook = _commandManager.workbook;
    Sheet? target;
    for (final sheet in workbook.sheets) {
      if (sheet.name == sheetName) {
        target = sheet;
        break;
      }
    }
    if (target == null) {
      return false;
    }
    final command = SetCellValueCommand(
      sheetName: target.name,
      row: row,
      column: column,
      value: _normaliseValue(newValue),
    );
    return _commandManager.execute(command);
  }

  /// Réinitialise la cellule.
  bool clear() => setValue(null);

  Object? _normaliseValue(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num || value is bool || value is String) {
      return value;
    }
    return value.toString();
  }
}

/// Coordonnées d'une plage rectangulaire.
class RangeCoordinates {
  RangeCoordinates({
    required this.startRow,
    required this.endRow,
    required this.startColumn,
    required this.endColumn,
  })  : assert(startRow >= 0),
        assert(endRow >= startRow),
        assert(startColumn >= 0),
        assert(endColumn >= startColumn);

  final int startRow;
  final int endRow;
  final int startColumn;
  final int endColumn;

  int get rowCount => endRow - startRow + 1;
  int get columnCount => endColumn - startColumn + 1;
}

class RangeApi {
  RangeApi._({
    required WorkbookCommandManager commandManager,
    required this.sheetName,
    required RangeCoordinates coordinates,
  })  : _commandManager = commandManager,
        _coordinates = coordinates;

  final WorkbookCommandManager _commandManager;
  final String sheetName;
  RangeCoordinates _coordinates;
  bool _lastResult = false;

  RangeCoordinates get coordinates => _coordinates;

  int get rowCount => _coordinates.rowCount;
  int get columnCount => _coordinates.columnCount;

  /// Résultat du dernier appel de mutation.
  bool get lastResult => _lastResult;

  /// Lecture synchrone des valeurs.
  List<List<Object?>> get values {
    final sheet = _resolveSheet();
    final result = <List<Object?>>[];
    for (var r = _coordinates.startRow; r <= _coordinates.endRow; r++) {
      final row = <Object?>[];
      for (var c = _coordinates.startColumn; c <= _coordinates.endColumn; c++) {
        row.add(sheet.rows[r][c].value);
      }
      result.add(List<Object?>.unmodifiable(row));
    }
    return List<List<Object?>>.unmodifiable(result);
  }

  /// Met à jour la plage avec les valeurs fournies.
  RangeApi setValues(List<List<Object?>> values) {
    if (values.isEmpty) {
      throw ArgumentError('values must not be empty.');
    }
    final expectedColumns = columnCount;
    if (values.any((row) => row.length != expectedColumns)) {
      throw ArgumentError('Chaque ligne doit contenir $expectedColumns éléments.');
    }
    if (values.length != rowCount) {
      throw ArgumentError('Le nombre de lignes doit être $rowCount.');
    }

    _lastResult = _commandManager.execute(
      SetRangeValuesCommand(
        sheetName: sheetName,
        startRow: _coordinates.startRow,
        startColumn: _coordinates.startColumn,
        values: values,
      ),
    );
    return this;
  }

  /// Attribue une valeur unique lorsque la plage ne contient qu'une cellule.
  RangeApi setValue(Object? value) {
    if (rowCount != 1 || columnCount != 1) {
      throw StateError('setValue ne peut être utilisé que sur une cellule.');
    }
    return setValues([
      [value]
    ]);
  }

  /// Efface le contenu de la plage.
  RangeApi clear() {
    final empty = List<List<Object?>>.generate(
      rowCount,
      (_) => List<Object?>.filled(columnCount, null),
    );
    return setValues(empty);
  }

  /// Recopie les données de la première ligne vers les suivantes.
  RangeApi fillDown() {
    _lastResult = _commandManager.execute(
      AutoFillRangeCommand(
        sheetName: sheetName,
        startRow: _coordinates.startRow,
        startColumn: _coordinates.startColumn,
        rowCount: rowCount,
        columnCount: columnCount,
        direction: RangeFillDirection.down,
      ),
    );
    return this;
  }

  /// Recopie les données de la première colonne vers les suivantes.
  RangeApi fillRight() {
    _lastResult = _commandManager.execute(
      AutoFillRangeCommand(
        sheetName: sheetName,
        startRow: _coordinates.startRow,
        startColumn: _coordinates.startColumn,
        rowCount: rowCount,
        columnCount: columnCount,
        direction: RangeFillDirection.right,
      ),
    );
    return this;
  }

  /// Trie les lignes de la plage.
  RangeApi sortByColumn([int columnIndex = 0, bool ascending = true]) {
    _lastResult = _commandManager.execute(
      SortRangeCommand(
        sheetName: sheetName,
        startRow: _coordinates.startRow,
        startColumn: _coordinates.startColumn,
        rowCount: rowCount,
        columnCount: columnCount,
        columnOffset: columnIndex,
        ascending: ascending,
      ),
    );
    return this;
  }

  /// Convertit les cellules en valeurs numériques.
  RangeApi formatAsNumber([int? decimalDigits]) {
    _lastResult = _commandManager.execute(
      FormatRangeAsNumberCommand(
        sheetName: sheetName,
        startRow: _coordinates.startRow,
        startColumn: _coordinates.startColumn,
        rowCount: rowCount,
        columnCount: columnCount,
        decimalDigits: decimalDigits,
      ),
    );
    return this;
  }

  /// Nettoie les textes en supprimant les espaces superflus.
  RangeApi autoFit() {
    _lastResult = _commandManager.execute(
      AutoFitRangeCommand(
        sheetName: sheetName,
        startRow: _coordinates.startRow,
        startColumn: _coordinates.startColumn,
        rowCount: rowCount,
        columnCount: columnCount,
      ),
    );
    return this;
  }

  Sheet _resolveSheet() {
    final workbook = _commandManager.workbook;
    for (final sheet in workbook.sheets) {
      if (sheet.name == sheetName) {
        return sheet;
      }
    }
    throw StateError('Feuille introuvable : $sheetName');
  }
}

class RowApi {
  RowApi._({
    required WorkbookCommandManager commandManager,
    required this.sheetName,
    required RangeCoordinates coordinates,
  })  : _range = RangeApi._(
          commandManager: commandManager,
          sheetName: sheetName,
          coordinates: coordinates,
        ),
        index = coordinates.startRow;

  final String sheetName;
  final RangeApi _range;

  /// Index de la ligne dans la feuille.
  final int index;

  bool get lastResult => _range.lastResult;

  /// Valeurs de la ligne.
  List<Object?> get values => _range.values.first;

  RowApi setValues(List<Object?> values) {
    if (values.length != _range.columnCount) {
      throw ArgumentError(
        'La ligne $index attend ${_range.columnCount} valeurs.',
      );
    }
    _range.setValues([values]);
    return this;
  }

  RowApi fillRight() {
    _range.fillRight();
    return this;
  }

  RowApi formatAsNumber([int? decimalDigits]) {
    _range.formatAsNumber(decimalDigits);
    return this;
  }

  RowApi autoFit() {
    _range.autoFit();
    return this;
  }

  RangeApi asRange() => _range;
}

class ColumnApi {
  ColumnApi._({
    required WorkbookCommandManager commandManager,
    required this.sheetName,
    required RangeCoordinates coordinates,
  })  : _range = RangeApi._(
          commandManager: commandManager,
          sheetName: sheetName,
          coordinates: coordinates,
        ),
        index = coordinates.startColumn;

  final String sheetName;
  final RangeApi _range;

  /// Index de la colonne dans la feuille.
  final int index;

  bool get lastResult => _range.lastResult;

  List<Object?> get values {
    final rows = _range.values;
    return List<Object?>.unmodifiable([
      for (final row in rows) row.first,
    ]);
  }

  ColumnApi setValues(List<Object?> values) {
    if (values.length != _range.rowCount) {
      throw ArgumentError(
        'La colonne $index attend ${_range.rowCount} valeurs.',
      );
    }
    final matrix = [
      for (final value in values) [value],
    ];
    _range.setValues(matrix);
    return this;
  }

  ColumnApi fillDown() {
    _range.fillDown();
    return this;
  }

  ColumnApi formatAsNumber([int? decimalDigits]) {
    _range.formatAsNumber(decimalDigits);
    return this;
  }

  ColumnApi autoFit() {
    _range.autoFit();
    return this;
  }

  RangeApi asRange() => _range;
}

class ChartApi {
  ChartApi._(this._sourceRange);

  RangeApi _sourceRange;

  RangeApi get range => _sourceRange;

  ChartApi updateRange(RangeApi range) {
    _sourceRange = range;
    return this;
  }

  Map<String, Object?> describe() {
    final coords = _sourceRange.coordinates;
    return <String, Object?>{
      'sheet': _sourceRange.sheetName,
      'startRow': coords.startRow,
      'endRow': coords.endRow,
      'startColumn': coords.startColumn,
      'endColumn': coords.endColumn,
    };
  }
}

class _RangeReferenceParser {
  _RangeReferenceParser(this.sheet);

  final Sheet sheet;

  RangeCoordinates? parse(String reference) {
    if (reference.isEmpty) {
      return null;
    }
    final cleaned = reference.trim();
    if (cleaned.isEmpty) {
      return null;
    }

    final parts = cleaned.split(':');
    if (parts.length == 1) {
      final start = CellPosition.tryParse(parts.first);
      if (start == null) {
        return null;
      }
      if (!_withinSheet(start)) {
        return null;
      }
      return RangeCoordinates(
        startRow: start.row,
        endRow: start.row,
        startColumn: start.column,
        endColumn: start.column,
      );
    }
    if (parts.length == 2) {
      final start = CellPosition.tryParse(parts.first);
      final end = CellPosition.tryParse(parts.last);
      if (start == null || end == null) {
        return null;
      }
      if (!_withinSheet(start) || !_withinSheet(end)) {
        return null;
      }
      final startRow = start.row < end.row ? start.row : end.row;
      final endRow = start.row > end.row ? start.row : end.row;
      final startColumn = start.column < end.column ? start.column : end.column;
      final endColumn = start.column > end.column ? start.column : end.column;
      return RangeCoordinates(
        startRow: startRow,
        endRow: endRow,
        startColumn: startColumn,
        endColumn: endColumn,
      );
    }
    return null;
  }

  bool _withinSheet(CellPosition position) {
    if (position.row < 0 || position.column < 0) {
      return false;
    }
    if (position.row >= sheet.rowCount) {
      return false;
    }
    if (position.column >= sheet.columnCount) {
      return false;
    }
    return true;
  }
}
