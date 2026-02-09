import 'package:bitacora_web/services/sheet_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SheetStore.init();
  });

  test('createNew generates unique ids during burst creation', () {
    final ids = List<String>.generate(120, (_) => SheetStore.createNew());
    final unique = ids.toSet();

    expect(unique.length, ids.length);

    final listedIds = SheetStore.list().map((s) => s.id).toSet();
    expect(listedIds.length, ids.length);
    expect(listedIds.containsAll(ids), isTrue);
  });

  test('createFromModel generates unique ids and keeps all sheets', () {
    final model = <String, dynamic>{
      'name': '',
      'savedAt': DateTime(2026, 2, 7).toIso8601String(),
      'headers': const ['A', 'B', 'Photos'],
      'colIds': const ['c_a', 'c_b', 'col_photos'],
      'rows': const <Map<String, dynamic>>[],
    };

    final ids = List<String>.generate(
      120,
      (_) => SheetStore.createFromModel(model),
    );
    final unique = ids.toSet();

    expect(unique.length, ids.length);

    final listedIds = SheetStore.list().map((s) => s.id).toSet();
    expect(listedIds.length, ids.length);
    expect(listedIds.containsAll(ids), isTrue);
  });
}
