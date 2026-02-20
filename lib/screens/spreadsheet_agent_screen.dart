import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../spreadsheet_agent/spreadsheet_agent.dart';
import '../ui/ui.dart';

class SpreadsheetAgentScreen extends StatefulWidget {
  const SpreadsheetAgentScreen({super.key});

  @override
  State<SpreadsheetAgentScreen> createState() => _SpreadsheetAgentScreenState();
}

class _SpreadsheetAgentScreenState extends State<SpreadsheetAgentScreen> {
  final SpreadsheetAgentFacade _agent = SpreadsheetAgentFacade();
  final TextEditingController _clientController =
      TextEditingController(text: 'default');
  final TextEditingController _pasteController = TextEditingController();
  final TextEditingController _defaultCentroController =
      TextEditingController();
  final TextEditingController _defaultProveedorController =
      TextEditingController();
  final TextEditingController _defaultObraController = TextEditingController();

  late String _templateId;
  SpreadsheetIngestResult? _ingest;
  Map<String, String> _headerToField = <String, String>{};
  List<Map<String, String>> _mappedRows = <Map<String, String>>[];
  SpreadsheetValidationReport? _report;
  List<SpreadsheetAuditEntry> _auditEntries = <SpreadsheetAuditEntry>[];
  bool _busy = false;

  SpreadsheetTemplate get _template => _agent.templateById(_templateId);

  @override
  void initState() {
    super.initState();
    _templateId = _agent.templates.first.id;
    _loadProfileAndAudit();
  }

  @override
  void dispose() {
    _clientController.dispose();
    _pasteController.dispose();
    _defaultCentroController.dispose();
    _defaultProveedorController.dispose();
    _defaultObraController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAndAudit() async {
    final clientId = _currentClientId();
    final profile = await _agent.loadProfile(
      templateId: _templateId,
      clientId: clientId,
    );

    if (!mounted) return;
    setState(() {
      if (profile != null) {
        _headerToField = Map<String, String>.from(profile.headerToField);
        _defaultCentroController.text =
            profile.defaultValues['centro_costo'] ?? '';
        _defaultProveedorController.text =
            profile.defaultValues['proveedor'] ?? '';
        _defaultObraController.text = profile.defaultValues['obra'] ?? '';
      }
    });

    final audit = await _agent.recentAudit(limit: 10);
    if (!mounted) return;
    setState(() => _auditEntries = audit);
  }

  String _currentClientId() {
    final raw = _clientController.text.trim();
    return raw.isEmpty ? 'default' : raw;
  }

  Map<String, String> _defaultValues() {
    return <String, String>{
      'centro_costo': _defaultCentroController.text.trim(),
      'proveedor': _defaultProveedorController.text.trim(),
      'obra': _defaultObraController.text.trim(),
    }..removeWhere((key, value) => value.isEmpty);
  }

  Future<void> _pickFile() async {
    final typeGroup = const XTypeGroup(
      label: 'Planillas',
      extensions: <String>['csv', 'xlsx'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return;

    setState(() => _busy = true);
    try {
      final ingested = await _agent.ingestFile(file);
      if (!mounted) return;
      final auto = _agent.autoMap(
        template: _template,
        sourceHeaders: ingested.headers,
        profileMap: _headerToField,
      );
      setState(() {
        _ingest = ingested;
        _headerToField = auto;
      });
      _runValidation();
      await _agent.addAudit(
        templateId: _template.id,
        clientId: _currentClientId(),
        action: 'ingest_file',
        detail: '${ingested.rows.length} filas desde ${file.name}',
      );
      _toast('Importado ${ingested.rows.length} filas desde ${file.name}.');
    } catch (e) {
      _toast('No se pudo importar el archivo: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _ingestPaste() async {
    final text = _pasteController.text;
    if (text.trim().isEmpty) {
      _toast('Pega una tabla primero.');
      return;
    }

    final ingested = _agent.ingestPaste(text);
    final auto = _agent.autoMap(
      template: _template,
      sourceHeaders: ingested.headers,
      profileMap: _headerToField,
    );
    setState(() {
      _ingest = ingested;
      _headerToField = auto;
    });
    _runValidation();
    await _agent.addAudit(
      templateId: _template.id,
      clientId: _currentClientId(),
      action: 'ingest_paste',
      detail: '${ingested.rows.length} filas desde pegado',
    );
    _toast('Pegado procesado: ${ingested.rows.length} filas.');
  }

  void _runValidation() {
    final ingest = _ingest;
    if (ingest == null) return;

    final mappedRows = _agent.transformRows(
      template: _template,
      headers: ingest.headers,
      rows: ingest.rows,
      headerToField: _headerToField,
      defaultValues: _defaultValues(),
    );
    final report = _agent.validate(
      template: _template,
      mappedRows: mappedRows,
    );

    setState(() {
      _mappedRows = mappedRows;
      _report = report;
    });
  }

  Future<void> _saveProfile() async {
    if (_ingest == null) {
      _toast('Importa o pega datos antes de guardar el perfil.');
      return;
    }
    await _agent.saveProfile(
      templateId: _templateId,
      clientId: _currentClientId(),
      headerToField: _headerToField,
      defaultValues: _defaultValues(),
    );
    await _loadProfileAndAudit();
    _toast('Perfil de mapeo guardado localmente.');
  }

  Future<void> _exportXlsx() async {
    if (_mappedRows.isEmpty) {
      _toast('No hay filas transformadas para exportar.');
      return;
    }
    if (_report?.hasErrors ?? false) {
      _toast('Corrige los errores de validación antes de exportar.');
      return;
    }
    final artifact = await _agent.exportXlsx(
      template: _template,
      mappedRows: _mappedRows,
      clientId: _currentClientId(),
    );
    await _loadProfileAndAudit();
    _toast('XLSX exportado: ${artifact.location}');
  }

  Future<void> _exportPdf() async {
    if (_mappedRows.isEmpty) {
      _toast('No hay filas transformadas para exportar.');
      return;
    }
    if (_report?.hasErrors ?? false) {
      _toast('Corrige los errores de validación antes de exportar.');
      return;
    }
    final artifact = await _agent.exportPdf(
      template: _template,
      mappedRows: _mappedRows,
      clientId: _currentClientId(),
    );
    await _loadProfileAndAudit();
    _toast('PDF exportado: ${artifact.location}');
  }

  void _toast(String message) {
    if (!mounted) return;
    AppToast.show(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bt = context.bitflow;
    final spacing = BitflowTokens.spacing;
    final ingest = _ingest;
    final report = _report;

    return AppShell(
      title: 'Agente de planillas',
      subtitle: 'Importa CSV/XLSX, mapea columnas y exporta sin backend.',
      leading: IconButton(
        tooltip: 'Volver',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      body: FocusTraversalGroup(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: AbsorbPointer(
                  absorbing: _busy,
                  child: ListView(
                    padding: EdgeInsets.all(spacing.s8),
                    children: <Widget>[
                      AppCard(
                        padding: EdgeInsets.all(spacing.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '1) Plantilla y cliente',
                              style: t.text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: spacing.s8),
                            DropdownButtonFormField<String>(
                              initialValue: _templateId,
                              decoration:
                                  const InputDecoration(labelText: 'Plantilla'),
                              items: _agent.templates
                                  .map(
                                    (template) => DropdownMenuItem<String>(
                                      value: template.id,
                                      child: Text(template.name),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value == null || value == _templateId) {
                                  return;
                                }
                                setState(() {
                                  _templateId = value;
                                  _headerToField = <String, String>{};
                                });
                                _loadProfileAndAudit();
                                _runValidation();
                              },
                            ),
                            SizedBox(height: spacing.s8),
                            TextField(
                              controller: _clientController,
                              decoration: const InputDecoration(
                                labelText: 'Cliente o preset',
                                hintText: 'ej: cliente_acme',
                              ),
                              onSubmitted: (_) => _loadProfileAndAudit(),
                            ),
                            SizedBox(height: spacing.s8),
                            Text(
                              _template.description,
                              style: bt.typography.caption,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spacing.s16),
                      AppCard(
                        padding: EdgeInsets.all(spacing.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '2) Importar o pegar',
                              style: t.text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: spacing.s8),
                            Wrap(
                              spacing: spacing.s8,
                              runSpacing: spacing.s8,
                              children: <Widget>[
                                AppButton(
                                  label: 'Importar CSV/XLSX',
                                  icon: Icons.upload_file_outlined,
                                  variant: AppButtonVariant.secondary,
                                  size: AppButtonSize.lg,
                                  onPressed: _pickFile,
                                ),
                                AppButton(
                                  label: 'Procesar pegado',
                                  icon: Icons.content_paste_go_outlined,
                                  variant: AppButtonVariant.primary,
                                  size: AppButtonSize.lg,
                                  onPressed: _ingestPaste,
                                ),
                              ],
                            ),
                            SizedBox(height: spacing.s8),
                            TextField(
                              controller: _pasteController,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText:
                                    'Pega una tabla copiada de mail, WhatsApp o Excel',
                              ),
                            ),
                            if (ingest != null) ...<Widget>[
                              SizedBox(height: spacing.s8),
                              Text(
                                'Fuente: ${ingest.sourceLabel} · Encabezados: ${ingest.headers.length} · Filas: ${ingest.rows.length}',
                                style: bt.typography.caption,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (ingest != null) ...[
                        SizedBox(height: spacing.s16),
                        AppCard(
                          padding: EdgeInsets.all(spacing.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '3) Mapear columnas y defaults',
                                style: t.text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: spacing.s12),
                              ...ingest.headers.map((header) {
                                final current = _headerToField[header];
                                return Padding(
                                  padding: EdgeInsets.only(bottom: spacing.s8),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          header,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: spacing.s12),
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          initialValue: current,
                                          decoration: const InputDecoration(
                                            labelText: 'Campo destino',
                                          ),
                                          items: <DropdownMenuItem<String>>[
                                            const DropdownMenuItem<String>(
                                              value: '',
                                              child: Text('Ignorar'),
                                            ),
                                            ..._template.fields.map(
                                              (field) =>
                                                  DropdownMenuItem<String>(
                                                value: field.key,
                                                child: Text(field.label),
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setState(() {
                                              final clean =
                                                  (value ?? '').trim();
                                              if (clean.isEmpty) {
                                                _headerToField.remove(header);
                                              } else {
                                                _headerToField[header] = clean;
                                              }
                                            });
                                            _runValidation();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              TextField(
                                controller: _defaultCentroController,
                                decoration: const InputDecoration(
                                  labelText: 'Default centro_costo',
                                ),
                                onChanged: (_) => _runValidation(),
                              ),
                              SizedBox(height: spacing.s8),
                              TextField(
                                controller: _defaultProveedorController,
                                decoration: const InputDecoration(
                                  labelText: 'Default proveedor',
                                ),
                                onChanged: (_) => _runValidation(),
                              ),
                              SizedBox(height: spacing.s8),
                              TextField(
                                controller: _defaultObraController,
                                decoration: const InputDecoration(
                                  labelText: 'Default obra',
                                ),
                                onChanged: (_) => _runValidation(),
                              ),
                              SizedBox(height: spacing.s12),
                              Wrap(
                                spacing: spacing.s8,
                                runSpacing: spacing.s8,
                                children: <Widget>[
                                  AppButton(
                                    label: 'Validar',
                                    icon: Icons.rule_folder_outlined,
                                    variant: AppButtonVariant.secondary,
                                    size: AppButtonSize.lg,
                                    onPressed: _runValidation,
                                  ),
                                  AppButton(
                                    label: 'Guardar preset local',
                                    icon: Icons.save_outlined,
                                    variant: AppButtonVariant.primary,
                                    size: AppButtonSize.lg,
                                    onPressed: _saveProfile,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (report != null) ...[
                        SizedBox(height: spacing.s16),
                        AppCard(
                          padding: EdgeInsets.all(spacing.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '4) Validación: ${report.errorCount} error(es), ${report.warningCount} advertencia(s)',
                                style: t.text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: spacing.s8),
                              if (report.issues.isEmpty)
                                const Text(
                                  'Sin observaciones. Listo para exportar.',
                                ),
                              ...report.issues.take(12).map(
                                    (issue) => Padding(
                                      padding:
                                          EdgeInsets.only(bottom: spacing.s4),
                                      child: Text(
                                        'Fila ${issue.row} · ${issue.field}: ${issue.message}${(issue.value ?? '').isEmpty ? '' : ' (${issue.value})'}',
                                        style: TextStyle(
                                          color: issue.isWarning
                                              ? Colors.orange.shade700
                                              : Colors.red.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ],
                      if (_mappedRows.isNotEmpty) ...[
                        SizedBox(height: spacing.s16),
                        AppCard(
                          padding: EdgeInsets.all(spacing.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '5) Preview y exportación',
                                style: t.text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: spacing.s8),
                              Text(
                                  'Filas transformadas: ${_mappedRows.length}'),
                              SizedBox(height: spacing.s8),
                              RepaintBoundary(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    columns: _template.fields
                                        .map(
                                          (f) => DataColumn(
                                            label: Text(f.label),
                                          ),
                                        )
                                        .toList(growable: false),
                                    rows: _mappedRows.take(12).map((row) {
                                      return DataRow(
                                        cells: _template.fields
                                            .map(
                                              (f) => DataCell(
                                                Text(row[f.key] ?? ''),
                                              ),
                                            )
                                            .toList(growable: false),
                                      );
                                    }).toList(growable: false),
                                  ),
                                ),
                              ),
                              SizedBox(height: spacing.s12),
                              Wrap(
                                spacing: spacing.s8,
                                runSpacing: spacing.s8,
                                children: <Widget>[
                                  AppButton(
                                    label: 'Exportar XLSX',
                                    icon: Icons.grid_on_outlined,
                                    variant: AppButtonVariant.primary,
                                    size: AppButtonSize.lg,
                                    onPressed: _exportXlsx,
                                  ),
                                  AppButton(
                                    label: 'Exportar PDF',
                                    icon: Icons.picture_as_pdf_outlined,
                                    variant: AppButtonVariant.secondary,
                                    size: AppButtonSize.lg,
                                    onPressed: _exportPdf,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_auditEntries.isNotEmpty) ...[
                        SizedBox(height: spacing.s16),
                        AppCard(
                          padding: EdgeInsets.all(spacing.s16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Historial local',
                                style: t.text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: spacing.s8),
                              ..._auditEntries.map(
                                (entry) => Padding(
                                  padding: EdgeInsets.only(bottom: spacing.s4),
                                  child: Text(
                                    '${entry.at.toLocal()} · ${entry.action} · ${entry.templateId}/${entry.clientId} · ${entry.detail}',
                                    style: bt.typography.caption,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_busy)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
