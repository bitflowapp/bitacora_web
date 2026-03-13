import 'package:bitacora_web/services/export_filename.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanitizeBitFlowSheetName normalizes spaces and symbols', () {
    final value = sanitizeBitFlowSheetName('  Obra Norte / lote #1  ');
    expect(value, 'Obra_Norte_lote_1');
  });

  test('buildBitFlowExportFileName uses commercial pattern', () {
    final fileName = buildBitFlowExportFileName(
      sheetName: '  Mi Hoja * QA ',
      extension: '.xlsx',
      now: DateTime(2026, 2, 13, 10, 12),
    );
    expect(fileName, 'BitFlow_2026-02-13_Mi_Hoja_QA.xlsx');
  });

  test('buildBitFlowBundleExportFileName uses full package pattern', () {
    final fileName = buildBitFlowBundleExportFileName(
      sheetName: '  Mi Hoja * QA ',
      now: DateTime(2026, 2, 13, 10, 12),
    );
    expect(fileName, 'BitFlow_Mi_Hoja_QA_2026-02-13_10-12.zip');
  });

  test('buildBitFlowPackageWorkbookFileName keeps sheet identity', () {
    final fileName = buildBitFlowPackageWorkbookFileName(
      sheetName: 'Inventario Norte',
    );
    expect(fileName, 'BitFlow_Inventario_Norte.xlsx');
  });

  test('buildBitFlowPackageReportFileName keeps sheet identity', () {
    final fileName = buildBitFlowPackageReportFileName(
      sheetName: 'Inventario Norte',
    );
    expect(fileName, 'BitFlow_Inventario_Norte.pdf');
  });

  test('buildBitFlowEvidenceFileName uses professional evidence naming', () {
    final fileName = buildBitFlowEvidenceFileName(
      kind: 'video',
      sheetName: 'Mediciones Técnicas',
      reference: 'E4',
      timestamp: DateTime(2026, 3, 10, 3, 1),
      extension: '.mp4',
    );
    expect(fileName, 'video_Mediciones_T_cnicas_E4_2026-03-10_03-01.mp4');
  });
}
