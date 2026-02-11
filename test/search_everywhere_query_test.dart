import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search query parse supports plain text', () {
    final query = SearchEverywhereQuery.parse('  Urgente  ');
    expect(query.needle, 'urgente');
    expect(query.columnToken, isNull);
    expect(query.hasColumnFilter, isFalse);
  });

  test('search query parse supports col:value syntax', () {
    final query = SearchEverywhereQuery.parse('Estado: En progreso ');
    expect(query.needle, 'en progreso');
    expect(query.columnToken, 'Estado');
    expect(query.hasColumnFilter, isTrue);
  });

  test('search query resolves aliases for estado/fecha', () {
    const queryStatus = SearchEverywhereQuery(
      raw: 'status:ok',
      needle: 'ok',
      columnToken: 'status',
    );
    const queryDate = SearchEverywhereQuery(
      raw: 'fecha:2026',
      needle: '2026',
      columnToken: 'fecha',
    );
    const headers = <String>['ID', 'Estado general', 'Fecha inspeccion'];
    expect(queryStatus.resolveColumnIndex(headers), 1);
    expect(queryDate.resolveColumnIndex(headers), 2);
  });
}
