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
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
      // No rompemos el flujo principal por el log local.
    }
  }

  Future<void> _refreshAuditOnly() async {
    final audit = await _agent.recentAudit(limit: 10);
    if (!mounted) return;
    setState(() => _auditEntries = audit);
  }

  Future<void> _pickFile() async {
    if (_busy) return;

    final messenger = ScaffoldMessenger.of(context);
    final typeGroup = const XTypeGroup(
      label: 'Planillas',
      extensions: <String>['csv', 'xlsx'],
    );

    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
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
      } catch (e) {
        if (!mounted) return;
        _showSnack(messenger,
            'No se pudo importar el archivo. Revisa el formato e intenta nuevamente.');
      }
    });
  }

  Future<void> _ingestPaste() async {
    if (_busy) return;

    final messenger = ScaffoldMessenger.of(context);
    final text = _pasteController.text;

    if (text.trim().isEmpty) {
      _showSnack(messenger, 'PegÃ¡ una tabla primero.');
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
        'ImportÃ¡ o pegÃ¡ datos antes de guardar perfil.',
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
        'CorregÃ­ los errores de validaciÃ³n antes de exportar.',
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
        'CorregÃ­ los errores de validaciÃ³n antes de exportar.',
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final cs = theme.colorScheme;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final normalized = query.trim().toLowerCase();
            final filtered = options.where((option) {
              if (normalized.isEmpty) return true;
              return option.value.toLowerCase().contains(normalized) ||
                  option.key.toLowerCase().contains(normalized);
            }).toList(growable: false);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mapear "$header"',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (options.length > 8) ...[
                      const SizedBox(height: 10),
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
                    ],
                    const SizedBox(height: 10),
                    Flexible(
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
                              shrinkWrap: true,
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
                                          ? cs.primary.withValues(alpha: 0.55)
                                          : cs.outlineVariant,
                                    ),
                                  ),
                                  tileColor: selected
                                      ? cs.primaryContainer
                                          .withValues(alpha: 0.55)
                                      : cs.surfaceContainerLow,
                                  title: Text(option.value),
                                  trailing: selected
                                      ? Icon(
                                          Icons.check_rounded,
                                          color: cs.primary,
                                        )
                                      : null,
                                  onTap: () => Navigator.of(sheetContext)
                                      .pop(option.key),
                                );
                              },
                            ),
                    ),
                  ],
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
        decoration: const InputDecoration(labelText: 'Campo destino'),
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

  @override
  Widget build(BuildContext context) {
    final ingest = _ingest;
    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agente de Planillas (MVP)'),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '1) Plantilla + cliente',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: _clientController,
                      decoration: const InputDecoration(
                        labelText: 'Cliente / preset',
                        hintText: 'ej: cliente_acme',
                      ),
                      onSubmitted: (_) => _loadProfileAndAudit(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _template.description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      '2) Importar o pegar',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: _pasteController,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText:
                            'PegÃ¡ acÃ¡ tabla copiada de mail/WhatsApp/Excel',
                      ),
                    ),
                    if (ingest != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Fuente: ${ingest.sourceLabel}  â€¢  Encabezados: ${ingest.headers.length}  â€¢  Filas: ${ingest.rows.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (ingest != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '3) Mapear columnas + defaults',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...ingest.headers.map((header) {
                        final current = (_headerToField[header] ?? '').trim();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  header,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _defaultCentroController,
                        decoration: const InputDecoration(
                          labelText: 'Default centro_costo',
                        ),
                        onChanged: (_) => _runValidation(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _defaultProveedorController,
                        decoration: const InputDecoration(
                          labelText: 'Default proveedor',
                        ),
                        onChanged: (_) => _runValidation(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _defaultObraController,
                        decoration: const InputDecoration(
                          labelText: 'Default obra',
                        ),
                        onChanged: (_) => _runValidation(),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
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
                ),
              ),
            if (report != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '4) Resultado validaciÃ³n: ${report.errorCount} errores, ${report.warningCount} warnings',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      if (report.issues.isEmpty)
                        const Text('Sin observaciones. Listo para exportar.'),
                      ...report.issues.take(12).map(
                            (issue) => Text(
                              'Fila ${issue.row} â€¢ ${issue.field}: ${issue.message}${(issue.value ?? '').isEmpty ? '' : ' (${issue.value})'}',
                              style: TextStyle(
                                color: issue.isWarning
                                    ? Colors.orange.shade700
                                    : Colors.red.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            if (_mappedRows.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '5) Preview + export',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text('Filas transformadas: ${_mappedRows.length}'),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: _template.fields
                              .map(
                                (f) => DataColumn(label: Text(f.label)),
                              )
                              .toList(growable: false),
                          rows: _mappedRows.take(12).map((row) {
                            return DataRow(
                              cells: _template.fields
                                  .map(
                                    (f) => DataCell(Text(row[f.key] ?? '')),
                                  )
                                  .toList(growable: false),
                            );
                          }).toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
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
                ),
              ),
            if (_auditEntries.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Audit log local',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ..._auditEntries.map(
                        (entry) => Text(
                          '${entry.at.toLocal()} â€¢ ${entry.action} â€¢ ${entry.templateId}/${entry.clientId} â€¢ ${entry.detail}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
