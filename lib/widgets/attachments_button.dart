// lib/widgets/attachments_button.dart
// Botón de adjuntos por fila (Web).
// Requiere AttachmentsServiceWeb y getCurrentRow().

import 'package:flutter/material.dart';
import '../services/attachments_service_web.dart';

typedef RowKeyProvider = (String sheetId, int rowIndex)? Function();

class AttachmentsButton extends StatefulWidget {
  const AttachmentsButton({
    super.key,
    required this.getCurrentRow,
    this.onChanged,
  });

  /// Debe devolver (sheetId, rowIndex) de la fila actual, o null si no hay selección.
  final RowKeyProvider getCurrentRow;

  /// Notifica al padre cuando cambian los adjuntos.
  final VoidCallback? onChanged;

  @override
  State<AttachmentsButton> createState() => _AttachmentsButtonState();
}

class _AttachmentsButtonState extends State<AttachmentsButton> {
  List<AttachmentRecord> _items = const [];
  (String sheetId, int rowIndex)? _row;

  Future<void> _reload() async {
    final loc = widget.getCurrentRow();
    _row = loc;
    if (loc == null) {
      if (mounted) {
        setState(() => _items = const []);
      }
      return;
    }

    final xs = await AttachmentsServiceWeb.I.listFor(
      sheetId: loc.$1,
      row: loc.$2,
    );
    if (!mounted) return;
    setState(() => _items = xs);
  }

  Future<void> _add() async {
    final loc = widget.getCurrentRow();
    _row = loc;
    if (loc == null) return;

    await AttachmentsServiceWeb.I.pickAndAdd(
      sheetId: loc.$1,
      row: loc.$2,
    );
    await _reload();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final hasItems = _items.isNotEmpty;
    final target = widget.getCurrentRow();
    final disabled = target == null;

    return Row(
      children: [
        IconButton(
          tooltip: 'Adjuntar archivos a esta fila',
          onPressed: disabled
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await _add();
                  if (!context.mounted) return;
                  final n = _items.length;
                  if (n > 0) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Adjuntos en esta fila: $n'),
                        duration: const Duration(milliseconds: 1500),
                      ),
                    );
                  }
                },
          icon: const Icon(Icons.attach_file),
        ),
        IconButton(
          tooltip: 'Ver adjuntos de la fila',
          onPressed: disabled
              ? null
              : () async {
                  await _reload();
                  if (!context.mounted || _row == null) return;

                  final selectedRow = _row!;
                  await showModalBottomSheet<void>(
                    context: context,
                    useSafeArea: true,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => _AttachmentsSheet(
                      sheetId: selectedRow.$1,
                      row: selectedRow.$2,
                      onChanged: widget.onChanged ?? () {},
                    ),
                  );
                  if (!mounted) return;
                  await _reload();
                  widget.onChanged?.call();
                },
          icon: Icon(hasItems ? Icons.folder_open : Icons.folder),
        ),
      ],
    );
  }
}

class _AttachmentsSheet extends StatefulWidget {
  const _AttachmentsSheet({
    required this.sheetId,
    required this.row,
    required this.onChanged,
  });

  final String sheetId;
  final int row;
  final VoidCallback onChanged;

  @override
  State<_AttachmentsSheet> createState() => _AttachmentsSheetState();
}

class _AttachmentsSheetState extends State<_AttachmentsSheet> {
  bool _loading = true;
  List<AttachmentRecord> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final xs = await AttachmentsServiceWeb.I.listFor(
      sheetId: widget.sheetId,
      row: widget.row,
    );
    if (!mounted) return;
    setState(() {
      _items = xs;
      _loading = false;
    });
  }

  Future<void> _add() async {
    await AttachmentsServiceWeb.I.pickAndAdd(
      sheetId: widget.sheetId,
      row: widget.row,
    );
    if (!mounted) return;
    await _load();
    widget.onChanged();
  }

  Future<void> _open(AttachmentRecord m) async {
    await AttachmentsServiceWeb.I.openInNewTab(m.id);
  }

  Future<void> _download(AttachmentRecord m) async {
    await AttachmentsServiceWeb.I.download(m.id);
  }

  Future<void> _delete(AttachmentRecord m) async {
    await AttachmentsServiceWeb.I.delete(m.id);
    if (!mounted) return;
    await _load();
    widget.onChanged();
  }

  IconData _iconFor(String mime) {
    if (mime.startsWith('image/')) return Icons.image;
    if (mime == 'application/pdf') return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  String _fmtSize(int b) {
    const kb = 1024;
    const mb = 1024 * 1024;
    if (b >= mb) return '${(b / mb).toStringAsFixed(1)} MB';
    if (b >= kb) return '${(b / kb).toStringAsFixed(1)} KB';
    return '$b B';
  }

  Widget _thumb(AttachmentRecord m) {
    if (!m.mime.startsWith('image/')) {
      return Icon(_iconFor(m.mime));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.memory(
        m.bytes,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = 'Adjuntos | Fila ${widget.row + 1}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Agregar',
            onPressed: _add,
            icon: const Icon(Icons.add_photo_alternate_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'No hay archivos adjuntos en esta fila.\nAgregá fotos, PDFs o archivos de respaldo.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: cs.outlineVariant),
                  itemBuilder: (_, i) {
                    final m = _items[i];
                    return ListTile(
                      leading: _thumb(m),
                      title: Text(
                        m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${m.mime} | ${_fmtSize(m.size)}'),
                      onTap: () => _open(m),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Abrir',
                            onPressed: () => _open(m),
                            icon: const Icon(Icons.open_in_new),
                          ),
                          IconButton(
                            tooltip: 'Descargar',
                            onPressed: () => _download(m),
                            icon: const Icon(Icons.download),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () => _delete(m),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: FilledButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.attach_file),
            label: const Text('Agregar archivos'),
          ),
        ),
      ),
    );
  }
}
