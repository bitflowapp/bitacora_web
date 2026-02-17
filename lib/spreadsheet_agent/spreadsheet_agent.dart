import 'package:file_selector/file_selector.dart';

import 'audit/audit_log.dart';
import 'export/exporter_pdf.dart';
import 'export/exporter_xlsx.dart';
import 'ingest/ingest_csv.dart';
import 'ingest/ingest_paste_table.dart';
import 'ingest/ingest_xlsx.dart';
import 'mapping/column_mapper.dart';
import 'mapping/mapping_profile.dart';
import 'spreadsheet_models.dart';
import 'templates/template_catalog.dart';
import 'validation/validator.dart';

export 'audit/audit_log.dart';
export 'mapping/mapping_profile.dart';
export 'spreadsheet_models.dart';
export 'templates/template_catalog.dart';

class SpreadsheetAgentFacade {
  SpreadsheetAgentFacade({
    SpreadsheetCsvIngest? csvIngest,
    SpreadsheetXlsxIngest? xlsxIngest,
    SpreadsheetPasteIngest? pasteIngest,
    SpreadsheetColumnMapper? mapper,
    SpreadsheetValidator? validator,
    SpreadsheetMappingProfileStore? profileStore,
    SpreadsheetXlsxExporter? xlsxExporter,
    SpreadsheetPdfExporter? pdfExporter,
    SpreadsheetAuditLogStore? auditStore,
  })  : _csvIngest = csvIngest ?? const SpreadsheetCsvIngest(),
        _xlsxIngest = xlsxIngest ?? const SpreadsheetXlsxIngest(),
        _pasteIngest = pasteIngest ?? const SpreadsheetPasteIngest(),
        _mapper = mapper ?? const SpreadsheetColumnMapper(),
        _validator = validator ?? const SpreadsheetValidator(),
        _profileStore = profileStore ?? const SpreadsheetMappingProfileStore(),
        _xlsxExporter = xlsxExporter ?? const SpreadsheetXlsxExporter(),
        _pdfExporter = pdfExporter ?? const SpreadsheetPdfExporter(),
        _auditStore = auditStore ?? const SpreadsheetAuditLogStore();

  final SpreadsheetCsvIngest _csvIngest;
  final SpreadsheetXlsxIngest _xlsxIngest;
  final SpreadsheetPasteIngest _pasteIngest;
  final SpreadsheetColumnMapper _mapper;
  final SpreadsheetValidator _validator;
  final SpreadsheetMappingProfileStore _profileStore;
  final SpreadsheetXlsxExporter _xlsxExporter;
  final SpreadsheetPdfExporter _pdfExporter;
  final SpreadsheetAuditLogStore _auditStore;

  List<SpreadsheetTemplate> get templates =>
      SpreadsheetTemplateCatalog.templates;

  SpreadsheetTemplate templateById(String id) =>
      SpreadsheetTemplateCatalog.byId(id);

  Future<SpreadsheetIngestResult> ingestFile(XFile file) async {
    final name = file.name.toLowerCase();
    final bytes = await file.readAsBytes();
    if (name.endsWith('.csv')) {
      return _csvIngest.fromBytes(bytes, sourceLabel: file.name);
    }
    if (name.endsWith('.xlsx')) {
      return _xlsxIngest.fromBytes(bytes, sourceLabel: file.name);
    }
    throw UnsupportedError('Formato no soportado: ${file.name}');
  }

  SpreadsheetIngestResult ingestPaste(String raw) {
    return _pasteIngest.fromText(raw, sourceLabel: 'Pegado');
  }

  Future<SpreadsheetMappingProfile?> loadProfile({
    required String templateId,
    required String clientId,
  }) {
    return _profileStore.load(templateId: templateId, clientId: clientId);
  }

  Future<void> saveProfile({
    required String templateId,
    required String clientId,
    required Map<String, String> headerToField,
    required Map<String, String> defaultValues,
  }) async {
    final profile = SpreadsheetMappingProfile(
      templateId: templateId,
      clientId: clientId,
      headerToField: Map<String, String>.from(headerToField),
      defaultValues: Map<String, String>.from(defaultValues),
      updatedAt: DateTime.now(),
    );
    await _profileStore.save(profile);
    await _auditStore.add(
      SpreadsheetAuditEntry(
        at: DateTime.now(),
        templateId: templateId,
        clientId: clientId,
        action: 'save_profile',
        detail: 'Headers mapeados: ${headerToField.length}',
      ),
    );
  }

  Map<String, String> autoMap({
    required SpreadsheetTemplate template,
    required List<String> sourceHeaders,
    Map<String, String> profileMap = const <String, String>{},
  }) {
    return _mapper.autoMap(
      template: template,
      sourceHeaders: sourceHeaders,
      profileMap: profileMap,
    );
  }

  List<Map<String, String>> transformRows({
    required SpreadsheetTemplate template,
    required List<String> headers,
    required List<List<String>> rows,
    required Map<String, String> headerToField,
    Map<String, String> defaultValues = const <String, String>{},
  }) {
    return _mapper.transformRows(
      template: template,
      headers: headers,
      rows: rows,
      headerToField: headerToField,
      defaultValues: defaultValues,
    );
  }

  SpreadsheetValidationReport validate({
    required SpreadsheetTemplate template,
    required List<Map<String, String>> mappedRows,
  }) {
    return _validator.validate(template: template, rows: mappedRows);
  }

  Future<SpreadsheetExportArtifact> exportXlsx({
    required SpreadsheetTemplate template,
    required List<Map<String, String>> mappedRows,
    required String clientId,
  }) async {
    final artifact = await _xlsxExporter.export(
      template: template,
      rows: mappedRows,
      fileBaseName: '${template.id}_$clientId',
    );
    await _auditStore.add(
      SpreadsheetAuditEntry(
        at: DateTime.now(),
        templateId: template.id,
        clientId: clientId,
        action: 'export_xlsx',
        detail: '${mappedRows.length} filas -> ${artifact.fileName}',
      ),
    );
    return artifact;
  }

  Future<SpreadsheetExportArtifact> exportPdf({
    required SpreadsheetTemplate template,
    required List<Map<String, String>> mappedRows,
    required String clientId,
  }) async {
    final artifact = await _pdfExporter.export(
      template: template,
      rows: mappedRows,
      fileBaseName: '${template.id}_$clientId',
    );
    await _auditStore.add(
      SpreadsheetAuditEntry(
        at: DateTime.now(),
        templateId: template.id,
        clientId: clientId,
        action: 'export_pdf',
        detail: '${mappedRows.length} filas -> ${artifact.fileName}',
      ),
    );
    return artifact;
  }

  Future<List<SpreadsheetAuditEntry>> recentAudit({int limit = 12}) {
    return _auditStore.recent(limit: limit);
  }

  Future<void> addAudit({
    required String templateId,
    required String clientId,
    required String action,
    required String detail,
  }) {
    return _auditStore.add(
      SpreadsheetAuditEntry(
        at: DateTime.now(),
        templateId: templateId,
        clientId: clientId,
        action: action,
        detail: detail,
      ),
    );
  }
}
