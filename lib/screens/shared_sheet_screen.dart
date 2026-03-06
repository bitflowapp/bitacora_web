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
  late Future<BitFlowShareLink?> _future;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<BitFlowShareLink?> _load() async {
    await BitFlowProductService.I.ensureInitialized();
    return BitFlowProductService.I.loadShareLink(widget.shareId);
  }

  Future<void> _openInWorkspace(BitFlowShareLink share) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final sheetId = await BitFlowProductService.I.importSharedSheet(
        share,
        preferOriginalSheetId: share.permission == BitFlowSharePermission.edit,
      );
      if (!mounted) return;
      context.go('/app/sheet/${Uri.encodeComponent(sheetId)}');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir la hoja compartida: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Sheet'),
        actions: [
          IconButton(
            onPressed: widget.onToggleTheme,
            icon: Icon(widget.isLight ? Icons.dark_mode : Icons.light_mode),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('No se pudo cargar el link compartido.'),
              ),
            );
          }
          final share = snapshot.data;
          if (share == null) {
            return const Center(child: Text('El link compartido no existe.'));
          }

          final model = _decodeModel(share.snapshotRawJson);
          final headers = (model['headers'] as List?)
                  ?.map((item) => (item ?? '').toString())
                  .toList(growable: false) ??
              const <String>[];
          final rows = _decodeRows(model['rows']);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                share.title.isEmpty ? 'Untitled sheet' : share.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                share.permission == BitFlowSharePermission.edit
                    ? 'Permiso: edit'
                    : 'Permiso: view',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              if ((share.ownerEmail ?? '').trim().isNotEmpty)
                Text(
                  'Owner: ${share.ownerEmail}',
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (headers.isEmpty)
                      const Text('No preview available.')
                    else
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: headers
                              .take(6)
                              .map((header) => DataColumn(label: Text(header)))
                              .toList(growable: false),
                          rows: rows
                              .take(5)
                              .map(
                                (row) => DataRow(
                                  cells: row
                                      .take(6)
                                      .map((cell) => DataCell(Text(cell)))
                                      .toList(growable: false),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _importing ? null : () => _openInWorkspace(share),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  _importing
                      ? 'Opening...'
                      : share.permission == BitFlowSharePermission.edit
                          ? 'Open editable'
                          : 'Save to my workspace',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: share.url));
                  if (!mounted) return;
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Link copied'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy link'),
              ),
            ],
          );
        },
      ),
    );
  }

  Map<String, dynamic> _decodeModel(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((key, value) => MapEntry(key.toString(), value));
      }
    } catch (_) {}
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
        out.add(row.map((item) => (item ?? '').toString()).toList());
      }
    }
    return out;
  }
}
