import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../spreadsheet_agent/spreadsheet_agent.dart';

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
  int _profileLoadToken = 0;

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

  void _showSnack(
      ScaffoldMessengerState messenger,
      String message,
      ) {
    final text = message.trim();
    if (text.isEmpty) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(text),
        ),
      );
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (!mounted) return;
      setState(() => _busy = false);
    }
  }

  Future<void> _loadProfileAndAudit() async {
    final loadToken = ++_profileLoadToken;
    final templateId = _templateId;
    final clientId = _currentClientId();

    final profileFuture = _agent.loadProfile(
      templateId: templateId,
      clientId: clientId,
    );
    final auditFuture = _agent.recentAudit(limit: 10);

    SpreadsheetMappingProfile? profile;
    List<SpreadsheetAuditEntry> audit = <SpreadsheetAuditEntry>[];

    try {
      profile = await profileFuture;
      audit = await auditFuture;
    } catch (_) {
      if (!mounted || loadToken != _profileLoadToken) return;

      setState(() {
        _headerToField = <String, String>{};
        _defaultCentroController.clear();
        _defaultProveedorController.clear();
        _defaultObraController.clear();
        _auditEntries = <SpreadsheetAuditEntry>[];
      });

      _runValidation();
      return;
    }

    if (!mounted || loadToken != _profileLoadToken) return;

    setState(() {
      if (profile != null) {
        _headerToField = Map<String, String>.from(profile.headerToField);
        _defaultCentroController.text =
            profile.defaultValues['centro_costo'] ?? '';
        _defaultProveedorController.text =
            profile.defaultValues['proveedor'] ?? '';
        _defaultObraController.text = profile.defaultValues['obra'] ?? '';
      } else {
        _headerToField = <String, String>{};
        _defaultCentroController.clear();
        _defaultProveedorController.clear();
        _defaultObraController.clear();
      }
      _auditEntries = audit;
    });

    _runValidation();
  }

  Future<void> _addAuditSafe({
    required String action,
    required String detail,
  }) async {
    try {
      await _agent.addAudit(
        templateId: _template.id,
        clientId: _currentClientId(),
        action: action,
        detail: detail,
      );
      await _refreshAuditOnly();
    } catch (_) {
      // No cortamos el flujo principal por fallos del log local.
    }
  }

  Future<void> _refreshAuditOnly() async {
    try {
      final audit = await _agent.recentAudit(limit: 10);
      if (!mounted) return;
      setState(() => _auditEntries = audit);
    } catch (_) {
      // Silencioso a propósito.
    }
  }

  Future<void> _pickFile() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);

    const typeGroup = XTypeGroup(
      label: 'Planillas',
      extensions: <String>['csv', 'xlsx'],
    );

    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[typeGroup],
    );
    if (file == null || !mounted) return;

    await _runBusy(() async {
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

        await _addAuditSafe(
          action: 'ingest_file',
          detail: '${ingested.rows.length} filas desde ${file.name}',
        );

        if (!mounted) return;
        _showSnack(
          messenger,
          'Importado ${ingested.rows.length} filas desde ${file.name}.',
        );
      } catch (_) {
        if (!mounted) return;
        _showSnack(
          messenger,
          'No se pudo importar el archivo. Revisá el formato e intentá nuevamente.',
        );
      }
    });
  }

  Future<void> _ingestPaste() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final text = _pasteController.text;

    if (text.trim().isEmpty) {
      _showSnack(messenger, 'Pegá una tabla primero.');
      return;
    }

    await _runBusy(() async {
      try {
        final ingested = _agent.ingestPaste(text);
        final auto = _agent.autoMap(
          template: _template,
          sourceHeaders: ingested.headers,
          profileMap: _headerToField,
        );

        if (!mounted) return;
        setState(() {
          _ingest = ingested;
          _headerToField = auto;
        });

        _runValidation();

        await _addAuditSafe(
          action: 'ingest_paste',
          detail: '${ingested.rows.length} filas desde pegado',
        );

        if (!mounted) return;
        _showSnack(
          messenger,
          'Pegado procesado: ${ingested.rows.length} filas.',
        );
      } catch (e) {
        if (!mounted) return;
        _showSnack(messenger, 'No se pudo procesar el pegado: $e');
      }
    });
  }

  void _runValidation() {
    final ingest = _ingest;
    if (ingest == null) {
      setState(() {
        _mappedRows = <Map<String, String>>[];
        _report = null;
      });
      return;
    }

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
      _showSnack(
        ScaffoldMessenger.of(context),
        'Importá o pegá datos antes de guardar el perfil.',
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    await _runBusy(() async {
      try {
        await _agent.saveProfile(
          templateId: _templateId,
          clientId: _currentClientId(),
          headerToField: _headerToField,
          defaultValues: _defaultValues(),
        );
        await _loadProfileAndAudit();

        if (!mounted) return;
        _showSnack(messenger, 'Perfil de mapeo guardado localmente.');
      } catch (e) {
        if (!mounted) return;
        _showSnack(messenger, 'No se pudo guardar el perfil: $e');
      }
    });
  }

  Future<void> _exportXlsx() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_mappedRows.isEmpty) {
      _showSnack(messenger, 'No hay filas transformadas para exportar.');
      return;
    }

    if (_report?.hasErrors ?? false) {
      _showSnack(
        messenger,
        'Corregí los errores de validación antes de exportar.',
      );
      return;
    }

    await _runBusy(() async {
      try {
        final artifact = await _agent.exportXlsx(
          template: _template,
          mappedRows: _mappedRows,
          clientId: _currentClientId(),
        );
        await _refreshAuditOnly();

        if (!mounted) return;
        _showSnack(messenger, 'XLSX exportado: ${artifact.location}');
      } catch (e) {
        if (!mounted) return;
        _showSnack(messenger, 'No se pudo exportar XLSX: $e');
      }
    });
  }

  Future<void> _exportPdf() async {
    final messenger = ScaffoldMessenger.of(context);

    if (_mappedRows.isEmpty) {
      _showSnack(messenger, 'No hay filas transformadas para exportar.');
      return;
    }

    if (_report?.hasErrors ?? false) {
      _showSnack(
        messenger,
        'Corregí los errores de validación antes de exportar.',
      );
      return;
    }

    await _runBusy(() async {
      try {
        final artifact = await _agent.exportPdf(
          template: _template,
          mappedRows: _mappedRows,
          clientId: _currentClientId(),
        );
        await _refreshAuditOnly();

        if (!mounted) return;
        _showSnack(messenger, 'PDF exportado: ${artifact.location}');
      } catch (e) {
        if (!mounted) return;
        _showSnack(messenger, 'No se pudo exportar PDF: $e');
      }
    });
  }

  bool _useBottomSheetMapping(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide < 700;
  }

  void _setHeaderMapping(String header, String value) {
    setState(() {
      final clean = value.trim();
      if (clean.isEmpty) {
        _headerToField.remove(header);
      } else {
        _headerToField[header] = clean;
      }
    });
    _runValidation();
  }

  String _fieldLabelForKey(String key) {
    if (key.trim().isEmpty) return 'Ignorar';
    for (final field in _template.fields) {
      if (field.key == key) return field.label;
    }
    return key;
  }

  Future<void> _pickHeaderMapping({
    required String header,
    required String currentValue,
  }) async {
    final options = <MapEntry<String, String>>[
      const MapEntry<String, String>('', 'Ignorar'),
      ..._template.fields.map(
            (field) => MapEntry<String, String>(field.key, field.label),
      ),
    ];

    String query = '';
    final searchController = TextEditingController();

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final cs = theme.colorScheme;
        final maxHeight =
        math.min(MediaQuery.of(sheetContext).size.height * 0.78, 560.0);

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final normalized = query.trim().toLowerCase();
            final filtered = options.where((option) {
              if (normalized.isEmpty) return true;
              return option.value.toLowerCase().contains(normalized) ||
                  option.key.toLowerCase().contains(normalized);
            }).toList(growable: false);

            return SafeArea(
              child: SizedBox(
                height: maxHeight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mapear "$header"',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (options.length > 8)
                        TextField(
                          controller: searchController,
                          onChanged: (value) =>
                              setSheetState(() => query = value),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Buscar campo...',
                            prefixIcon: Icon(Icons.search_rounded),
                          ),
                        ),
                      if (options.length > 8) const SizedBox(height: 10),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                          child: Text(
                            'Sin resultados para "$query".',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )
                            : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                          itemBuilder: (ctx, index) {
                            final option = filtered[index];
                            final selected = option.key == currentValue;

                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: selected
                                      ? cs.primary.withOpacity(0.55)
                                      : cs.outline.withOpacity(0.25),
                                ),
                              ),
                              tileColor: selected
                                  ? cs.primaryContainer.withOpacity(0.55)
                                  : cs.surface,
                              title: Text(option.value),
                              subtitle: option.key.isEmpty
                                  ? null
                                  : Text(
                                option.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: selected
                                  ? Icon(
                                Icons.check_rounded,
                                color: cs.primary,
                              )
                                  : null,
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(option.key),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();

    if (picked == null) return;
    _setHeaderMapping(header, picked);
  }

  Widget _buildMappingPicker({
    required BuildContext context,
    required String header,
    required String currentValue,
  }) {
    final allowedKeys = <String>{'', ..._template.fields.map((f) => f.key)};
    final selectedValue =
    allowedKeys.contains(currentValue) ? currentValue : '';

    if (!_useBottomSheetMapping(context)) {
      return DropdownButtonFormField<String>(
        key: ValueKey<String>('$_templateId|$header|$selectedValue'),
        initialValue: selectedValue,
        decoration: const InputDecoration(
          labelText: 'Campo destino',
        ),
        items: <DropdownMenuItem<String>>[
          const DropdownMenuItem<String>(
            value: '',
            child: Text('Ignorar'),
          ),
          ..._template.fields.map(
                (field) => DropdownMenuItem<String>(
              value: field.key,
              child: Text(field.label),
            ),
          ),
        ],
        onChanged: (value) => _setHeaderMapping(header, value ?? ''),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _pickHeaderMapping(
          header: header,
          currentValue: selectedValue,
        ),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Campo destino',
            suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
          ),
          child: Text(
            _fieldLabelForKey(selectedValue),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  String _issueText(SpreadsheetValidationIssue issue) {
    final value = (issue.value ?? '').trim();
    if (value.isEmpty) {
      return 'Fila ${issue.row} · ${issue.field}: ${issue.message}';
    }
    return 'Fila ${issue.row} · ${issue.field}: ${issue.message} ($value)';
  }

  @override
  Widget build(BuildContext context) {
    final ingest = _ingest;
    final report = _report;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agente de Planillas'),
        actions: [
          IconButton(
            tooltip: 'Recargar perfiles y audit log',
            onPressed: _busy ? null : _loadProfileAndAudit,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          AbsorbPointer(
            absorbing: _busy,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 980;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SectionCard(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Transformación y exportación',
                      subtitle:
                      'Importá una planilla o pegá una tabla, mapeá columnas, validá y exportá a XLSX o PDF.',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(
                            icon: Icons.description_outlined,
                            label: _template.name,
                          ),
                          _InfoChip(
                            icon: Icons.badge_outlined,
                            label: _currentClientId(),
                          ),
                          if (ingest != null)
                            _InfoChip(
                              icon: Icons.table_rows_outlined,
                              label: '${ingest.rows.length} filas',
                            ),
                          if (report != null)
                            _InfoChip(
                              icon: report.hasErrors
                                  ? Icons.error_outline_rounded
                                  : Icons.verified_outlined,
                              label:
                              '${report.errorCount} errores · ${report.warningCount} warnings',
                              tone: report.hasErrors
                                  ? _ChipTone.danger
                                  : _ChipTone.success,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTemplateCard(context)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildImportCard(context)),
                        ],
                      )
                    else ...[
                      _buildTemplateCard(context),
                      const SizedBox(height: 16),
                      _buildImportCard(context),
                    ],
                    if (ingest != null) ...[
                      const SizedBox(height: 16),
                      _buildMappingCard(context, ingest),
                    ],
                    if (report != null) ...[
                      const SizedBox(height: 16),
                      _buildValidationCard(context, report),
                    ],
                    if (_mappedRows.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildPreviewCard(context),
                    ],
                    if (_auditEntries.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildAuditCard(context),
                    ],
                    const SizedBox(height: 24),
                    if (_busy)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Procesando...',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (_busy)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.layers_outlined,
      title: '1) Plantilla + cliente',
      subtitle: 'Elegí la plantilla, definí el preset y cargá defaults.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _templateId,
            decoration: const InputDecoration(
              labelText: 'Plantilla',
            ),
            items: _agent.templates
                .map(
                  (template) => DropdownMenuItem<String>(
                value: template.id,
                child: Text(template.name),
              ),
            )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null || value == _templateId) return;
              setState(() {
                _templateId = value;
                _headerToField = <String, String>{};
                _report = null;
              });
              _loadProfileAndAudit();
              _runValidation();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clientController,
            decoration: const InputDecoration(
              labelText: 'Cliente / preset',
              hintText: 'ej: cliente_acme',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _loadProfileAndAudit(),
          ),
          const SizedBox(height: 12),
          Text(
            _template.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard(BuildContext context) {
    final ingest = _ingest;

    return _SectionCard(
      icon: Icons.input_rounded,
      title: '2) Importar o pegar',
      subtitle: 'Admite CSV/XLSX o pegado directo desde mail, WhatsApp o Excel.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Importar CSV/XLSX'),
              ),
              FilledButton.icon(
                onPressed: _ingestPaste,
                icon: const Icon(Icons.content_paste_go_outlined),
                label: const Text('Procesar pegado'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pasteController,
            maxLines: 6,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Pegá acá una tabla copiada de mail, WhatsApp o Excel',
            ),
          ),
          if (ingest != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.source_outlined,
                  label: ingest.sourceLabel,
                ),
                _InfoChip(
                  icon: Icons.view_column_outlined,
                  label: '${ingest.headers.length} encabezados',
                ),
                _InfoChip(
                  icon: Icons.table_rows_outlined,
                  label: '${ingest.rows.length} filas',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMappingCard(
      BuildContext context,
      SpreadsheetIngestResult ingest,
      ) {
    return _SectionCard(
      icon: Icons.alt_route_rounded,
      title: '3) Mapeo + defaults',
      subtitle:
      'Asigná cada encabezado al campo destino y completá valores por defecto.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...ingest.headers.map((header) {
            final current = (_headerToField[header] ?? '').trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 720;

                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          header,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildMappingPicker(
                          context: context,
                          header: header,
                          currentValue: current,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          header,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMappingPicker(
                          context: context,
                          header: header,
                          currentValue: current,
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          }),
          const SizedBox(height: 6),
          TextField(
            controller: _defaultCentroController,
            decoration: const InputDecoration(
              labelText: 'Default centro_costo',
            ),
            onChanged: (_) => _runValidation(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _defaultProveedorController,
            decoration: const InputDecoration(
              labelText: 'Default proveedor',
            ),
            onChanged: (_) => _runValidation(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _defaultObraController,
            decoration: const InputDecoration(
              labelText: 'Default obra',
            ),
            onChanged: (_) => _runValidation(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _runValidation,
                icon: const Icon(Icons.rule_folder_outlined),
                label: const Text('Validar'),
              ),
              OutlinedButton.icon(
                onPressed: _saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar preset local'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildValidationCard(
      BuildContext context,
      SpreadsheetValidationReport report,
      ) {
    final issues = report.issues.take(12).toList(growable: false);

    return _SectionCard(
      icon: report.hasErrors
          ? Icons.report_problem_outlined
          : Icons.verified_outlined,
      title: '4) Resultado de validación',
      subtitle:
      '${report.errorCount} errores · ${report.warningCount} warnings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (report.issues.isEmpty)
            const Text('Sin observaciones. Listo para exportar.')
          else
            ...issues.map(
                  (issue) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: issue.isWarning
                      ? Colors.orange.withOpacity(0.08)
                      : Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: issue.isWarning
                        ? Colors.orange.withOpacity(0.28)
                        : Colors.red.withOpacity(0.28),
                  ),
                ),
                child: Text(
                  _issueText(issue),
                  style: TextStyle(
                    color: issue.isWarning
                        ? Colors.orange.shade800
                        : Colors.red.shade800,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.visibility_outlined,
      title: '5) Preview + export',
      subtitle: 'Vista previa de las filas transformadas antes de exportar.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filas transformadas: ${_mappedRows.length}'),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 40,
                dataRowMaxHeight: 56,
                columns: _template.fields
                    .map(
                      (f) => DataColumn(label: Text(f.label)),
                )
                    .toList(growable: false),
                rows: _mappedRows.take(12).map((row) {
                  return DataRow(
                    cells: _template.fields
                        .map(
                          (f) => DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 90,
                            maxWidth: 220,
                          ),
                          child: Text(
                            row[f.key] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                        .toList(growable: false),
                  );
                }).toList(growable: false),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _exportXlsx,
                icon: const Icon(Icons.grid_on_outlined),
                label: const Text('Exportar XLSX'),
              ),
              OutlinedButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Exportar PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditCard(BuildContext context) {
    return _SectionCard(
      icon: Icons.history_rounded,
      title: 'Audit log local',
      subtitle: 'Últimas acciones registradas en el dispositivo.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _auditEntries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.18),
                ),
              ),
              child: Text(
                '${entry.at.toLocal()} · ${entry.action} · ${entry.templateId}/${entry.clientId} · ${entry.detail}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: cs.outline.withOpacity(0.10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

enum _ChipTone {
  neutral,
  success,
  danger,
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final _ChipTone tone;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.tone = _ChipTone.neutral,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bg;
    Color fg;
    Color border;

    switch (tone) {
      case _ChipTone.success:
        bg = Colors.green.withOpacity(0.10);
        fg = Colors.green.shade800;
        border = Colors.green.withOpacity(0.22);
        break;
      case _ChipTone.danger:
        bg = Colors.red.withOpacity(0.10);
        fg = Colors.red.shade800;
        border = Colors.red.withOpacity(0.22);
        break;
      case _ChipTone.neutral:
        bg = cs.surfaceVariant.withOpacity(0.55);
        fg = cs.onSurfaceVariant;
        border = cs.outline.withOpacity(0.16);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}