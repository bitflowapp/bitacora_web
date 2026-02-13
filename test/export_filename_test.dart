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
}
