import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../services/bitflow_product_models.dart';
import '../services/bitflow_product_service.dart';

class SharedSheetScreen extends StatefulWidget {
  const SharedSheetScreen({
    super.key,
    required this.shareId,
    required this.isLight,
    required this.onToggleTheme,
  });

  final String shareId;
  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<SharedSheetScreen> createState() => _SharedSheetScreenState();
}

class _SharedSheetScreenState extends State<SharedSheetScreen> {
  static const int _maxPreviewColumns = 6;
  static const int _maxPreviewRows = 5;

  late Future<BitFlowShareLink?> _future;
  bool _importing = false;
  bool _copying = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant SharedSheetScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shareId != widget.shareId) {
      _future = _load();
    }
  }

  Future<BitFlowShareLink?> _load() async {
    await BitFlowProductService.I.ensureInitialized();
    return BitFlowProductService.I.loadShareLink(widget.shareId);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    final text = message.trim();
    if (text.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openInWorkspace(BitFlowShareLink share) async {
    if (_importing) return;

    final router = GoRouter.of(context);

    setState(() => _importing = true);
    try {
      final sheetId = await BitFlowProductService.I.importSharedSheet(
        share,
        preferOriginalSheetId: share.permission == BitFlowSharePermission.edit,
      );

      if (!mounted) return;
      router.go('/app/sheet/${Uri.encodeComponent(sheetId)}');
    } catch (_) {
      _showSnack('No se pudo abrir la hoja compartida.');
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _copyLink(String url) async {
    if (_copying) return;

    final value = url.trim();
    if (value.isEmpty) {
      _showSnack('El link compartido no es valido.');
      return;
    }

    setState(() => _copying = true);
    try {
      await Clipboard.setData(ClipboardData(text: value));
      _showSnack('Link copiado.');
    } catch (_) {
      _showSnack('No se pudo copiar el link.');
    } finally {
      if (mounted) {
        setState(() => _copying = false);
      }
    }
  }

  Map<String, dynamic> _decodeModel(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      // Mantener preview vacio si el snapshot esta danado.
    }
    return <String, dynamic>{};
  }

  List<List<String>> _decodeRows(Object? rawRows) {
    if (rawRows is! List) return const <List<String>>[];

    final out = <List<String>>[];

    for (final row in rawRows) {
      if (row is Map) {
        final cells = (row['cells'] as List?)
                ?.map((item) => (item ?? '').toString())
                .toList(growable: false) ??
            const <String>[];
        out.add(cells);
      } else if (row is List) {
        out.add(
          row.map((item) => (item ?? '').toString()).toList(growable: false),
        );
      }
    }

    return out;
  }

  List<String> _buildPreviewHeaders(List<String> headers) {
    final trimmed = headers
        .map((header) => header.trim().isEmpty ? 'â€”' : header.trim())
        .take(_maxPreviewColumns)
        .toList(growable: false);

    return trimmed;
  }

  List<String> _normalizePreviewRow(
    List<String> row,
    int visibleColumnCount,
  ) {
    final values = row.take(visibleColumnCount).toList(growable: true);
    while (values.length < visibleColumnCount) {
      values.add('');
    }
    return values;
  }

  Widget _buildPreviewCard(
    ThemeData theme, {
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final previewHeaders = _buildPreviewHeaders(headers);
    final visibleColumnCount = previewHeaders.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vista previa',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (previewHeaders.isEmpty)
            Text(
              'No hay vista previa disponible.',
              style: theme.textTheme.bodyMedium,
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: previewHeaders
                    .map(
                      (header) => DataColumn(
                        label: Text(
                          header,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                rows: rows.take(_maxPreviewRows).map((row) {
                  final normalized = _normalizePreviewRow(
                    row,
                    visibleColumnCount,
                  );
                  return DataRow(
                    cells: normalized
                        .map(
                          (cell) => DataCell(
                            Text(
                              cell,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                }).toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off_rounded, size: 42),
              const SizedBox(height: 12),
              const Text(
                'No se pudo cargar el link compartido.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _reload,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 42),
              const SizedBox(height: 12),
              const Text(
                'El link compartido no existe o ya no esta disponible.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _reload,
                child: const Text('Volver a cargar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoja compartida'),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isLight ? Icons.dark_mode : Icons.light_mode),
            tooltip: widget.isLight ? 'Modo oscuro' : 'Modo claro',
          ),
        ],
      ),
      body: FutureBuilder<BitFlowShareLink?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _buildErrorState();
          }

          final share = snapshot.data;
          if (share == null) {
            return _buildMissingState();
          }

          final model = _decodeModel(share.snapshotRawJson);
          final headers = (model['headers'] as List?)
                  ?.map((item) => (item ?? '').toString())
                  .toList(growable: false) ??
              const <String>[];
          final rows = _decodeRows(model['rows']);

          final title = share.title.trim().isEmpty
              ? 'Hoja sin titulo'
              : share.title.trim();
          final owner = (share.ownerEmail ?? '').trim();
          final isEditable = share.permission == BitFlowSharePermission.edit;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isEditable ? 'Permiso: edicion' : 'Permiso: solo lectura',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              if (owner.isNotEmpty)
                Text(
                  'Propietario: $owner',
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 20),
              _buildPreviewCard(
                theme,
                headers: headers,
                rows: rows,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _importing ? null : () => _openInWorkspace(share),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  _importing
                      ? 'Abriendo...'
                      : isEditable
                          ? 'Abrir editable'
                          : 'Guardar en mi espacio',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _copying ? null : () => _copyLink(share.url),
                icon: const Icon(Icons.copy_rounded),
                label: Text(_copying ? 'Copiando...' : 'Copiar link'),
              ),
            ],
          );
        },
      ),
    );
  }
}
