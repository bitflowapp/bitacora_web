import 'package:bitacora_web/corporate/corporate_models.dart';
import 'package:bitacora_web/corporate/local_corporate_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CorporateRole parses minimum phase 1 roles', () {
    expect(CorporateRole.fromValue('tecnico'), CorporateRole.tecnico);
    expect(CorporateRole.fromValue('supervisor'), CorporateRole.supervisor);
    expect(CorporateRole.fromValue('coordinador'), CorporateRole.coordinador);
    expect(CorporateRole.fromValue('admin'), CorporateRole.admin);
    expect(CorporateRole.fromValue('unknown'), CorporateRole.tecnico);
  });

  test('local corporate repository exposes workspace and projects', () async {
    const repository = LocalCorporateRepository();
    final workspaces = await repository.listWorkspaces();
    expect(workspaces, hasLength(1));
    expect(workspaces.single.role, CorporateRole.admin);

    final projects = await repository.listProjects(workspaces.single.id);
    expect(projects.length, greaterThanOrEqualTo(3));
    expect(
      projects.map((project) => project.fieldScope),
      contains('Proteccion catodica'),
    );
  });
}
