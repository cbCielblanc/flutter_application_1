import '../../commands/clear_sheet_command.dart';
import '../../commands/insert_column_command.dart';
import '../../commands/insert_row_command.dart';
import '../../commands/set_cell_value_command.dart';
import '../../commands/workbook_command_manager.dart';
import '../../domain/cell.dart';
import '../../domain/sheet.dart';
import '../../domain/workbook.dart';
import '../../state/sheet_selection_state.dart';

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
