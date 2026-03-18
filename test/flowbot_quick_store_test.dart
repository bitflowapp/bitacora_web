import 'package:bitacora_web/services/flowbot_quick_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recent commands persist by context and stay deduped', () {
    final encoded = FlowBotQuickStore.encodeRecentByContext(
      <String, List<String>>{
        'sheet:a': <String>[
          'poner OK en B2',
          'poner OK en B2',
          'duplicar fila 3'
        ],
        'sheet:b': <String>['agregar columna Observaciones'],
      },
      limit: 6,
    );

    final decoded = FlowBotQuickStore.decodeRecentByContext(encoded, limit: 6);

    expect(decoded['sheet:a'], <String>['poner OK en B2', 'duplicar fila 3']);
    expect(decoded['sheet:b'], <String>['agregar columna Observaciones']);
  });

  test('rememberRecent keeps newest first and respects limit', () {
    final next = FlowBotQuickStore.rememberRecent(
      <String>[
        'duplicar fila 3',
        'borrar B2',
        'agregar columna Observaciones',
      ],
      'borrar B2',
      limit: 3,
    );

    expect(
      next,
      <String>[
        'borrar B2',
        'duplicar fila 3',
        'agregar columna Observaciones',
      ],
    );
  });

  test('recent commands drop conversational noise and failed chatter', () {
    final encoded = FlowBotQuickStore.encodeRecentByContext(
      <String, List<String>>{
        'sheet:a': <String>[
          'hola hola',
          'poner OK en B2',
          'gracias',
          'duplicar fila 3',
        ],
      },
      limit: 6,
    );

    final decoded = FlowBotQuickStore.decodeRecentByContext(encoded, limit: 6);
    expect(decoded['sheet:a'], <String>['poner OK en B2', 'duplicar fila 3']);

    final remembered = FlowBotQuickStore.rememberRecent(
      <String>['poner OK en B2'],
      'hola hola',
      limit: 6,
    );
    expect(remembered, <String>['poner OK en B2']);
  });

  test('favorites persist by context and toggle cleanly', () {
    final entry = FlowBotFavoriteShortcut(
      kind: 'quick_action',
      label: 'Duplicar fila actual',
      quickActionId: 'duplicate-row',
      updatedAtMs: 10,
    );

    final toggledOn = FlowBotQuickStore.toggleFavorite(
      const <FlowBotFavoriteShortcut>[],
      entry,
      limit: 6,
      nowMs: 99,
    );
    expect(toggledOn, hasLength(1));
    expect(toggledOn.single.quickActionId, 'duplicate-row');

    final encoded = FlowBotQuickStore.encodeFavoritesByContext(
      <String, List<FlowBotFavoriteShortcut>>{
        'sheet:a': toggledOn,
      },
      limit: 6,
    );
    final decoded = FlowBotQuickStore.decodeFavoritesByContext(
      encoded,
      limit: 6,
    );
    expect(decoded['sheet:a'], hasLength(1));
    expect(decoded['sheet:a']!.single.quickActionId, 'duplicate-row');

    final toggledOff = FlowBotQuickStore.toggleFavorite(
      toggledOn,
      entry,
      limit: 6,
      nowMs: 120,
    );
    expect(toggledOff, isEmpty);
  });
}
