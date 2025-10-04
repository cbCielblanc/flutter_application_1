import '../../state/sheet_selection_state.dart';

typedef SelectionStateResolver = SheetSelectionState? Function(String pageKey);

class ScriptNavigatorBinding {
  const ScriptNavigatorBinding({this.selectionStateFor});

  final SelectionStateResolver? selectionStateFor;
}
