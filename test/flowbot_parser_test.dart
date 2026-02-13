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

  test('parses fill range using current selection', () {
    final result = parser.parse(
      'rellenar listo x 3',
      selectedRow: 4,
      selectedCol: 2,
    );

    expect(result.actions, hasLength(1));
    final action = result.actions.first;
    expect(action.type, FlowBotActionType.fillRange);
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

  test('parses alignment and wrap commands', () {
    final result = parser.parse(
      'alinear columna B a centro; wrap columna B a 3 lineas',
      selectedRow: 0,
      selectedCol: 0,
    );

    expect(result.actions, hasLength(2));
    expect(result.actions.first.type, FlowBotActionType.setColumnAlign);
    expect(result.actions.first.column, 1);
    expect(result.actions.first.align, 'center');
    expect(result.actions.last.type, FlowBotActionType.setWrap);
    expect(result.actions.last.column, 1);
    expect(result.actions.last.lines, 3);
  });

  test('parses "fila nueva con gps y fecha"', () {
    final result = parser.parse(
      'fila nueva con gps y fecha',
      selectedRow: 2,
      selectedCol: 1,
    );

    expect(result.actions, isNotEmpty);
    expect(
      result.actions.any((a) => a.type == FlowBotActionType.addRow),
      isTrue,
    );
    expect(
      result.actions.any((a) => a.type == FlowBotActionType.setToday),
      isTrue,
    );
  });

  test('parses "nuevo registro" as add row automation', () {
    final result = parser.parse(
      'nuevo registro',
      selectedRow: 0,
      selectedCol: 0,
    );

    expect(result.actions, isNotEmpty);
    expect(result.actions.first.type, FlowBotActionType.addRow);
  });

  test('parses quick field pattern command in spanish', () {
    final result = parser.parse(
      'progresiva 120, estado ok, fecha hoy, obs revisar',
      selectedRow: 0,
      selectedCol: 0,
    );

    expect(result.actions, isNotEmpty);
    expect(result.actions.first.type, FlowBotActionType.autoId);
    expect(result.actions.first.start, 120);
    expect(
      result.actions.any((a) => a.type == FlowBotActionType.applyStatus),
      isTrue,
    );
    expect(
      result.actions.any((a) => a.type == FlowBotActionType.setToday),
      isTrue,
    );
  });

  test('parses progressive fill command with step and rows', () {
    final result = parser.parse(
      'rellenar progresiva desde 1200 cada 25 por 40 filas',
      selectedRow: 0,
      selectedCol: 0,
    );

    expect(result.actions, hasLength(1));
    final action = result.actions.first;
    expect(action.type, FlowBotActionType.autoId);
    expect(action.start, 1200);
    expect(action.step, 25);
    expect(action.count, 40);
  });

  test('parses "pegar tabla"', () {
    final result = parser.parse(
      'pegar tabla',
      selectedRow: 0,
      selectedCol: 0,
    );
    expect(result.actions, hasLength(1));
    expect(result.actions.first.type, FlowBotActionType.pasteTable);
  });

  test('parses "exportar paquete completo"', () {
    final result = parser.parse(
      'exportar paquete completo',
      selectedRow: 0,
      selectedCol: 0,
    );
    expect(result.actions, hasLength(1));
    expect(result.actions.first.type, FlowBotActionType.exportBundle);
  });

  test('accepts apply confirmation variants', () {
    expect(parser.isApplyConfirmation('aceptar'), isTrue);
    expect(parser.isApplyConfirmation('aplicar'), isTrue);
    expect(parser.isApplyConfirmation('ok'), isTrue);
    expect(parser.isApplyConfirmation('aplicar cambios.'), isTrue);
    expect(parser.isApplyConfirmation('poner OK en B2'), isFalse);
  });
}
