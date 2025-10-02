import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/state/sheet_selection_state.dart';

void main() {
  group('SheetSelectionState formulas', () {
    test('updates dependent cells when references change', () {
      final state = SheetSelectionState();
      const a1 = CellPosition(0, 0);
      const b1 = CellPosition(0, 1);

      state.selectCell(a1);
      state.updateEditingValue('2');
      state.commitEditingValue();

      state.selectCell(b1);
      state.updateEditingValue('=A1+3');
      state.commitEditingValue();

      expect(state.valueFor(b1), equals('5'));

      state.selectCell(a1);
      state.updateEditingValue('7');
      state.commitEditingValue();

      expect(state.valueFor(b1), equals('10'));
    });
  });
  group('SheetSelectionState text', () {
    test('preserves multiline plain text', () {
      final state = SheetSelectionState();
      const a1 = CellPosition(0, 0);

      state.selectCell(a1);
      state.updateEditingValue('Line 1\nLine 2');
      state.commitEditingValue();

      expect(state.valueFor(a1), equals('Line 1\nLine 2'));
      expect(state.rawValueFor(a1), equals('Line 1\nLine 2'));
    });
  });
}
