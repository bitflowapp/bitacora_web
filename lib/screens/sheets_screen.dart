// lib/screens/sheets_screen.dart
import 'package:flutter/material.dart';

import '../services/sheet_store.dart';
import 'editor_screen.dart';

class SheetsScreen extends StatefulWidget {
  const SheetsScreen({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<SheetsScreen> createState() => _SheetsScreenState();
}

class _SheetsScreenState extends State<SheetsScreen> {
  List<SheetMeta> _items = <SheetMeta>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _items = SheetStore.list();
      _loading = false;
    });
  }

  Future<void> _handleRefresh() async {
    _load();
  }

  Future<void> _open(String id) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        // EditorScreen ahora requiere isLight / onToggleTheme / sheetId.
        builder: (_) => EditorScreen(
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
          sheetId: id,
        ),
      ),
    );
    if (!mounted) return;
    _load();
  }

  Future<void> _openLastSheet() async {
    final last = _lastUpdatedSheet;
    if (last == null) return;
    await _open(last.id);
  }

  Future<void> _newBlank() async {
    final id = SheetStore.createNew();
    if (!mounted) return;
    await _open(id);
  }

  Future<void> _newFromTemplate(TemplateKind kind) async {
    final id = SheetStore.createFromTemplate(kind);
    if (!mounted) return;
    await _open(id);
  }

  void _showTemplates() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_rows),
              title: const Text('Relevamiento resistividades'),
              subtitle: const Text(
                'Fecha, Progresiva, 1m, 3m, 5m, Observaciones',
              ),
              onTap: () {
                Navigator.pop(context);
                _newFromTemplate(TemplateKind.resistividades);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Inventario simple'),
              subtitle: const Text('Ítem, Cantidad, Unidad, Ubicación, Nota'),
              onTap: () {
                Navigator.pop(context);
                _newFromTemplate(TemplateKind.inventario);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Checklist diario'),
              subtitle: const Text(
                'Tarea, Responsable, Estado, Hora, Comentario',
              ),
              onTap: () {
                Navigator.pop(context);
                _newFromTemplate(TemplateKind.checklist);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _renameSheet(SheetMeta it) async {
    final controller = TextEditingController(text: it.title);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar planilla'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej: Relevamiento Pozo 12',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final newTitle = result.trim();
    if (newTitle.isEmpty) return;

    SheetStore.rename(it.id, newTitle);
    if (!mounted) return;
    _load();
  }

  Future<void> _deleteWithConfirm(SheetMeta it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar planilla'),
        content: Text(
          '¿Eliminar "${it.title.isEmpty ? 'Planilla ${it.id}' : it.title}"? '
              'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    if (!mounted) return;

    SheetStore.delete(it.id);
    _load();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Planilla eliminada'),
        duration: Duration(milliseconds: 1400),
      ),
    );
  }

  String _formatUpdatedAt(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();

    String hhmm(DateTime x) =>
        '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';

    final sameDay =
        local.year == now.year && local.month == now.month && local.day == now.day;
    if (sameDay) {
      return 'Hoy ${hhmm(local)}';
    }
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm ${hhmm(local)}';
  }

  SheetMeta? get _lastUpdatedSheet {
    if (_items.isEmpty) return null;
    SheetMeta latest = _items[0];
    for (int i = 1; i < _items.length; i++) {
      final it = _items[i];
      if (it.updatedAt.isAfter(latest.updatedAt)) {
        latest = it;
      }
    }
    return latest;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF020617) : const Color(0xFFF3F4F6);

    final last = _lastUpdatedSheet;
    final subtitleText = () {
      if (_loading) {
        return 'Cargando planillas...';
      }
      if (_items.isEmpty) {
        return 'Sin planillas guardadas todavía';
      }
      final lastLabel = last != null ? _formatUpdatedAt(last.updatedAt) : '—';
      return '${_items.length} planillas · Última: $lastLabel';
    }();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bit Flow',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitleText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_items.isNotEmpty && !_loading)
            IconButton(
              tooltip: 'Abrir última planilla',
              onPressed: _openLastSheet,
              icon: const Icon(Icons.history_toggle_off),
            ),
          IconButton(
            tooltip:
            widget.isLight ? 'Cambiar a modo oscuro' : 'Cambiar a modo claro',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              widget.isLight ? Icons.dark_mode : Icons.light_mode,
            ),
          ),
          IconButton(
            tooltip: 'Plantillas',
            onPressed: _showTemplates,
            icon: const Icon(Icons.view_quilt_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(strokeWidth: 2.6),
      )
          : _items.isEmpty
          ? _Empty(onNew: _newBlank, onTemplates: _showTemplates)
          : RefreshIndicator(
        onRefresh: _handleRefresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView.separated(
                  padding:
                  const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final it = _items[i];
                    final title = it.title.isNotEmpty
                        ? it.title
                        : 'Planilla ${it.id}';
                    final subtitle =
                        'Actualizada: ${_formatUpdatedAt(it.updatedAt)} · Filas: ${it.rows}';

                    return Dismissible(
                      key: ValueKey<String>(it.id),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _deleteWithConfirm(it);
                        return false;
                      },
                      background: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.error
                              .withValues(alpha: 0.08),
                          borderRadius:
                          BorderRadius.circular(18),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          color: cs.error,
                        ),
                      ),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(18),
                          side: BorderSide(
                            color: theme.dividerColor
                                .withValues(alpha: 0.65),
                            width: 0.7,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _open(it.id),
                          onLongPress: () => _renameSheet(it),
                          child: Padding(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 6,
                            ),
                            child: ListTile(
                              contentPadding:
                              const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 4,
                              ),
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: cs
                                    .primaryContainer
                                    .withValues(alpha: 0.85),
                                child: const Icon(
                                  Icons.table_chart,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                title,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                subtitle,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () =>
                                    _deleteWithConfirm(it),
                                icon: const Icon(
                                  Icons.delete_outline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton.extended(
        onPressed: _newBlank,
        label: const Text('Nueva hoja'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.onNew,
    required this.onTemplates,
  });

  final VoidCallback onNew;
  final VoidCallback onTemplates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark
        ? const Color(0xFF020617)
        : const Color(0xFFFFFFFF);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Card(
                elevation: 0,
                color: cardBg.withValues(alpha: 0.98),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color:
                    theme.dividerColor.withValues(alpha: 0.7),
                    width: 0.8,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.table_chart_outlined,
                        size: 56,
                        color: cs.primary,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Todavía no hay planillas',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Creá una hoja nueva o arrancá desde una plantilla para tus relevamientos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).hintColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: onNew,
                            icon: const Icon(Icons.add),
                            label: const Text('Nueva hoja'),
                          ),
                          OutlinedButton.icon(
                            onPressed: onTemplates,
                            icon: const Icon(
                              Icons.view_quilt_outlined,
                            ),
                            label: const Text('Plantillas'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
