import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../services/save_file.dart';
import '../spreadsheet_models.dart';

class SpreadsheetPdfExporter {
  const SpreadsheetPdfExporter();

  Future<SpreadsheetExportArtifact> export({
    required SpreadsheetTemplate template,
    required List<Map<String, String>> rows,
    String fileBaseName = 'agente_planillas',
  }) async {
    final doc = pw.Document();

    final headers = template.fields.map((f) => f.label).toList(growable: false);
    final tableRows = rows
        .take(250)
        .map(
          (row) => template.fields
              .map((field) => (row[field.key] ?? '').trim())
              .toList(growable: false),
        )
        .toList(growable: false);

    doc.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(24),
        ),
        build: (context) {
          return <pw.Widget>[
            pw.Text(
              template.name,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Filas exportadas: ${tableRows.length}'),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: tableRows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor(0.92, 0.94, 1.0),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey400),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3,
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await doc.save();
    final safeBaseName = fileBaseName.trim().isEmpty ? 'agente_planillas' : fileBaseName.trim();
    final fileName = '$safeBaseName.pdf';
    final saved = await saveBytes(fileName, bytes);

    return SpreadsheetExportArtifact(
      fileName: fileName,
      location: saved,
      bytes: bytes.length,
    );
  }
}
