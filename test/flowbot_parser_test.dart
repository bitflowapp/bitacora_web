import 'package:bitacora_web/services/flowbot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = RuleBasedFlowBot();

  test('parses set command with A1 reference', () {
    final result = parser.parse(
      'poner OK en B2',
      selectedRow: 0,
      selectedCol: 0,
    );

    expect(result.actions, hasLength(1));
    final action = result.actions.first;
    expect(action.type, FlowBotActionType.setCell);
    expect(action.row, 1);
    expect(action.col, 1);
    expect(action.value, 'OK');
  });

  test('parses fill down using current selection', () {
    final result = parser.parse(
      'rellenar listo x 3',
      selectedRow: 4,
      selectedCol: 2,
    );

    expect(result.actions, hasLength(1));
    final action = result.actions.first;
    expect(action.type, FlowBotActionType.fillDown);
    expect(action.row, 4);
    expect(action.col, 2);
    expect(action.count, 3);
    expect(action.value, 'listo');
  });

  test('parses add row and set by row/col', () {
    final result = parser.parse(
      'agregar fila y poner pendiente en fila 3 columna 2',
      selectedRow: 0,
      selectedCol: 0,
    );

    expect(result.actions.length, 2);
    expect(result.actions.first.type, FlowBotActionType.addRow);
    expect(result.actions.last.type, FlowBotActionType.setCell);
    expect(result.actions.last.row, 2);
    expect(result.actions.last.col, 1);
    expect(result.actions.last.value, 'pendiente');
  });
}
