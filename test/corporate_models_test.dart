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

  test('local repository exposes linked sheet ids for PC project', () async {
    const repository = LocalCorporateRepository();

    final sheetIds =
        await repository.listProjectSheetIds('local_project_pc_gasoducto');

    expect(sheetIds, isNotEmpty);
    expect(sheetIds, contains('local_sheet_default'));
  });

  test('local repository linkSheetToProject is a safe no-op', () async {
    const repository = LocalCorporateRepository();

    await expectLater(
      repository.linkSheetToProject('local_project_pc_gasoducto', 'sheet-1'),
      completes,
    );
  });

  test('local repository row review methods stay empty and safe', () async {
    const repository = LocalCorporateRepository();

    final review = await repository.getRowReview(
      'local_project_pc_gasoducto',
      'local_sheet_default',
      'row-1',
    );
    expect(review, isNull);

    final reviews = await repository.listSheetRowReviews(
      'local_project_pc_gasoducto',
      'local_sheet_default',
    );
    expect(reviews, isEmpty);

    final evidenceLinks = await repository.listRowEvidenceLinks(
      'local_project_pc_gasoducto',
      'local_sheet_default',
      rowId: 'row-1',
    );
    expect(evidenceLinks, isEmpty);

    await expectLater(
      repository.upsertRowReview(
        const RowReview(
          projectId: 'local_project_pc_gasoducto',
          sheetLocalId: 'local_sheet_default',
          rowId: 'row-1',
          status: 'observada',
        ),
      ),
      completes,
    );

    await expectLater(
      repository.linkRowEvidence(
        const RowEvidenceLink(
          projectId: 'local_project_pc_gasoducto',
          sheetLocalId: 'local_sheet_default',
          rowId: 'row-1',
          evidenceRef: 'mem:row-1-photo-1',
        ),
      ),
      completes,
    );
  });
}
