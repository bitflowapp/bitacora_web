import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merge maps applies non-conflicting imported cells', () {
    final result = PackageMergeEngine.mergeMaps(
      local: <String, String>{
        'r1::c_estado': 'Pendiente',
        'r1::c_desc': 'A',
      },
      imported: <String, String>{
        'r1::c_desc': 'A',
        'r2::c_estado': 'Urgente',
      },
      conflictPolicy: PackageMergeConflictPolicy.keepLocal,
    );

    expect(result.conflicts, isEmpty);
    expect(result.merged['r1::c_estado'], 'Pendiente');
    expect(result.merged['r2::c_estado'], 'Urgente');
    expect(result.importedApplied, 1);
  });

  test('merge maps keeps local value on conflict when policy is keepLocal', () {
    final result = PackageMergeEngine.mergeMaps(
      local: const <String, String>{'r1::c_estado': 'Pendiente'},
      imported: const <String, String>{'r1::c_estado': 'Completado'},
      conflictPolicy: PackageMergeConflictPolicy.keepLocal,
    );

    expect(result.conflicts.length, 1);
    expect(result.merged['r1::c_estado'], 'Pendiente');
  });

  test('merge maps uses imported value on conflict when policy is useImported',
      () {
    final result = PackageMergeEngine.mergeMaps(
      local: const <String, String>{'r1::c_estado': 'Pendiente'},
      imported: const <String, String>{'r1::c_estado': 'Completado'},
      conflictPolicy: PackageMergeConflictPolicy.useImported,
    );

    expect(result.conflicts.length, 1);
    expect(result.merged['r1::c_estado'], 'Completado');
    expect(result.importedApplied, 1);
  });
}
