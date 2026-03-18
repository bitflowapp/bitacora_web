import 'package:bitacora_web/features/editor/export/editor_export_result_mapper.dart';
import 'package:bitacora_web/features/editor/export/editor_export_result_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = EditorExportResultMapper();

  test('maps saved outcome to banner with open actions when available', () {
    final outcome = EditorExportOutcomeFactory.saved(
      name: 'control_diario.xlsx',
      shareRequested: false,
      includeAttachments: false,
      savedPath: '/tmp/cierre/control_diario.xlsx',
    );

    final state = mapper.map(
      outcome,
      capabilities: const EditorExportResultCapabilities(
        canOpenFile: true,
        canOpenLocation: true,
      ),
    );

    expect(state.outcome.kind, EditorExportOutcomeKind.saved);
    expect(state.banner.title, 'Archivo guardado');
    expect(state.banner.formatLabel, 'XLSX');
    expect(
      state.banner.actions.map((action) => action.label).toList(),
      <String>['Abrir archivo', 'Ver carpeta', 'Seguir editando'],
    );
    expect(state.banner.isError, isFalse);
  });

  test('maps system sheet outcome with honest share retry label', () {
    final outcome = EditorExportOutcomeFactory.systemSheetOpened(
      name: 'control_diario.xlsx',
      includeAttachments: true,
    );

    final state = mapper.map(outcome);

    expect(state.banner.title, 'Opciones del sistema abiertas');
    expect(
      state.banner.actions.map((action) => action.label).toList(),
      <String>['Abrir compartir', 'Seguir editando', 'Cerrar editor'],
    );
    expect(state.banner.isRecoverable, isTrue);
    expect(state.banner.isError, isFalse);
  });

  test('maps unsupported outcome as error without retry actions', () {
    final outcome = EditorExportOutcomeFactory.unsupported(
      fileName: 'control_diario.xlsx',
      format: 'xlsx',
      shareRequested: true,
      includeAttachments: false,
    );

    final state = mapper.map(outcome);

    expect(state.banner.title, 'Salida no disponible');
    expect(state.banner.isError, isTrue);
    expect(
      state.banner.actions.map((action) => action.action).toList(),
      <EditorExportResultAction>[EditorExportResultAction.continueEditing],
    );
  });
}
