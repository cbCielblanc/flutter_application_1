import 'package:meta/meta.dart';

import 'dart/dart_script_engine.dart';
import 'descriptor.dart';
import 'scope.dart';

export 'scope.dart';
export 'descriptor.dart';

@immutable
class ScriptDocument {
  const ScriptDocument({
    required this.id,
    required this.name,
    required this.scope,
    required this.module,
    required this.exports,
    required this.signatures,
  });

  final String id;
  final String name;
  final ScriptScope scope;
  final DartScriptModule module;
  final Map<String, DartScriptExport> exports;
  final Map<String, DartScriptSignature> signatures;

  Iterable<String> get exportNames => exports.keys;

  Iterable<String> get signatureNames => signatures.keys;

  DartScriptExport? operator [](String name) => exports[name];

  DartScriptSignature? signatureFor(String name) => signatures[name];

  ScriptDocument copyWith({
    DartScriptModule? module,
    Map<String, DartScriptExport>? exports,
    Map<String, DartScriptSignature>? signatures,
  }) {
    return ScriptDocument(
      id: id,
      name: name,
      scope: scope,
      module: module ?? this.module,
      exports: exports ?? this.exports,
      signatures: signatures ?? this.signatures,
    );
  }
}

enum ScriptEventType {
  workbookOpen,
  workbookClose,
  workbookBeforeSave,
  pageEnter,
  pageLeave,
  worksheetActivate,
  worksheetDeactivate,
  cellChanged,
  selectionChanged,
  notesChanged,
  worksheetBeforeSingleClick,
  worksheetBeforeDoubleClick,
}

extension ScriptEventTypeLabel on ScriptEventType {
  String get wireName {
    switch (this) {
      case ScriptEventType.workbookOpen:
        return 'workbook.open';
      case ScriptEventType.workbookClose:
        return 'workbook.close';
      case ScriptEventType.workbookBeforeSave:
        return 'workbook.beforeSave';
      case ScriptEventType.pageEnter:
        return 'page.enter';
      case ScriptEventType.pageLeave:
        return 'page.leave';
      case ScriptEventType.worksheetActivate:
        return 'worksheet.activate';
      case ScriptEventType.worksheetDeactivate:
        return 'worksheet.deactivate';
      case ScriptEventType.cellChanged:
        return 'cell.changed';
      case ScriptEventType.selectionChanged:
        return 'selection.changed';
      case ScriptEventType.notesChanged:
        return 'notes.changed';
      case ScriptEventType.worksheetBeforeSingleClick:
        return 'worksheet.beforeSingleClick';
      case ScriptEventType.worksheetBeforeDoubleClick:
        return 'worksheet.beforeDoubleClick';
    }
  }

  static ScriptEventType parse(String value) {
    switch (value) {
      case 'workbook.open':
        return ScriptEventType.workbookOpen;
      case 'workbook.close':
        return ScriptEventType.workbookClose;
      case 'workbook.beforeSave':
        return ScriptEventType.workbookBeforeSave;
      case 'page.enter':
        return ScriptEventType.pageEnter;
      case 'page.leave':
        return ScriptEventType.pageLeave;
      case 'worksheet.activate':
        return ScriptEventType.worksheetActivate;
      case 'worksheet.deactivate':
        return ScriptEventType.worksheetDeactivate;
      case 'cell.changed':
        return ScriptEventType.cellChanged;
      case 'selection.changed':
        return ScriptEventType.selectionChanged;
      case 'notes.changed':
        return ScriptEventType.notesChanged;
      case 'worksheet.beforeSingleClick':
        return ScriptEventType.worksheetBeforeSingleClick;
      case 'worksheet.beforeDoubleClick':
        return ScriptEventType.worksheetBeforeDoubleClick;
      default:
        throw ArgumentError('Evenement inconnu: $value');
    }
  }
}
