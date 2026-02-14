import 'package:bitacora_web/services/flowbot.dart';
import 'package:bitacora_web/services/flowbot_macro_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macro store encodes and decodes presets', () {
    final presets = <FlowBotMacroPreset>[
      const FlowBotMacroPreset(name: 'Macro 1', command: 'poner OK en A1'),
      const FlowBotMacroPreset(name: 'Macro 2', command: 'fecha hoy'),
    ];
    final raw = FlowBotMacroStore.encode(presets);
    final decoded = FlowBotMacroStore.decode(raw);

    expect(decoded, hasLength(2));
    expect(decoded.first.name, 'Macro 1');
    expect(decoded.first.command, 'poner OK en A1');
    expect(decoded.last.name, 'Macro 2');
  });

  test('macro command can be parsed and applied on controlled grid model', () {
    const parser = RuleBasedFlowBot();
    final actions = parser
        .parse(
          'poner OK en A1',
          selectedRow: 0,
          selectedCol: 0,
        )
        .actions;
    final grid = <List<String>>[
      <String>['', ''],
    ];

    for (final action in actions) {
      if (action.type == FlowBotActionType.setCell) {
        final row = action.row ?? 0;
        final col = action.col ?? 0;
        while (row >= grid.length) {
          grid.add(<String>['', '']);
        }
        grid[row][col] = action.value ?? '';
      }
    }

    expect(grid[0][0], 'OK');
  });
}
