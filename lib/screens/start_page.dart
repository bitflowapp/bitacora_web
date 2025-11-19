// lib/screens/start_page.dart
// Inicio con acentos arcoíris, divertido pero profesional.
// Pensado para Bitácora Web / Bit Flow, listo para producción.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../workers/json_worker.dart';
import '../services/sheet_store.dart';
import '../services/export_xlsx_service.dart';
import '../widgets/glass_appbar.dart';
import 'editor_screen.dart';

class StartPage extends StatefulWidget {
  const StartPage({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<StartPage> createState() => _StartPageState();
}

enum _ViewMode { list, grid }
enum _SortMode { updatedDesc, titleAsc, rowsDesc }

class _StartPageState extends State<StartPage> {
  List<SheetMeta> _items = <SheetMeta>[];
  String _q = '';
  _ViewMode _view = _ViewMode.list;
  _SortMode _sort = _SortMode.updatedDesc;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _items = SheetStore.list();
    });
  }

  Future<void> _newSheet() async {
    final id = SheetStore.createNew();
    _reload();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      _NoAnimRoute(
        // EditorScreen con tema + id de planilla.
        child: EditorScreen(
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
          sheetId: id,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
  }

  Future<void> _rename(SheetMeta m) async {
    final controller = TextEditingController(text: m.title);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Renombrar planilla'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Título',
            hintText: 'Ej: Relevamiento Pozo 12',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (value) =>
              Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;

    SheetStore.rename(m.id, trimmed);
    _reload();
  }

  Future<void> _open(SheetMeta m) async {
    await Navigator.push<void>(
      context,
      _NoAnimRoute(
        child: EditorScreen(
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
          sheetId: m.id,
        ),
      ),
    );
    if (!mounted) return;
    _reload();
  }

  String _fmt(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) return 'justo ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';

    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd/$mm $hh:$min';
  }

  Future<void> _exportSheet(SheetMeta m) async {
    final raw = SheetStore.loadRaw(m.id);
    if (raw == null) {
      _toast('No se pudo leer la planilla.');
      return;
    }

    try {
      final parsed = await JsonWorker.parseOnce(raw);
      final name =
      _sanitizeFileName(m.title.isEmpty ? 'bitacora' : m.title);

      await ExportXlsxService.download(
        // Importante: acá va el nombre base, sin “.xlsx”
        fileName: name,
        headers: parsed.headers,
        rows: parsed.rows,
        // Si tu JsonWorker ya trae más info (photoRows, GPS, etc.),
        // acá se pueden mapear igual que en EditorScreen.
      );

      _toast('Exportado como $name.xlsx');
    } catch (e) {
      _toast('Error al exportar XLSX: $e');
    }
  }

  String _sanitizeFileName(String s) {
    final r = RegExp(r'[\\/:*?"<>|]+');
    final cleaned = s.trim().replaceAll(r, '_');
    return cleaned.isEmpty ? 'bitacora' : cleaned;
  }

  void _toast(String msg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------- Derivados UI ----------

  List<SheetMeta> get _filteredSorted {
    var list = _q.isEmpty
        ? List<SheetMeta>.from(_items)
        : _items
        .where(
          (e) => (e.title.isEmpty ? 'Planilla' : e.title)
          .toLowerCase()
          .contains(_q.toLowerCase()),
    )
        .toList();

    list.sort((a, b) {
      switch (_sort) {
        case _SortMode.updatedDesc:
          return b.updatedAt.compareTo(a.updatedAt);
        case _SortMode.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _SortMode.rowsDesc:
          return b.rows.compareTo(a.rows);
      }
    });
    return list;
  }

  ({int total, int today, int totalRows}) get _stats {
    final now = DateTime.now();
    int total = _items.length;
    int today = 0;
    int totalRows = 0;

    for (final m in _items) {
      final d = m.updatedAt.toLocal();
      if (d.year == now.year &&
          d.month == now.month &&
          d.day == now.day) {
        today++;
      }
      totalRows += m.rows;
    }
    return (total: total, today: today, totalRows: totalRows);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final isLightTheme = theme.brightness == Brightness.light;
    final data = _filteredSorted;
    final s = _stats;

    final bg = isLightTheme
        ? const Color(0xFFF3F4F6)
        : const Color(0xFF020617);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        titleSpacing: 8,
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    c.primary,
                    c.secondary,
                    c.tertiary,
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.grid_on_rounded,
                size: 15,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Bitácora Web'),
            const SizedBox(width: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: c.primary.withValues(alpha: 0.08),
                border: Border.all(
                  color: c.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Text(
                'Bit Flow',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.primary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
        flexibleSpace: GlassAppBarBackground(isLight: isLightTheme),
        actions: [
          _SortMenu(
            current: _sort,
            onChanged: (v) => setState(() => _sort = v),
          ),
          IconButton(
            tooltip: _view == _ViewMode.list
                ? 'Vista de grilla'
                : 'Vista de lista',
            onPressed: () {
              setState(() {
                _view = _view == _ViewMode.list
                    ? _ViewMode.grid
                    : _ViewMode.list;
              });
            },
            icon: Icon(
              _view == _ViewMode.list
                  ? Icons.grid_view_rounded
                  : Icons.view_list_rounded,
            ),
          ),
          IconButton(
            tooltip:
            isLightTheme ? 'Cambiar a oscuro' : 'Cambiar a claro',
            onPressed: widget.onToggleTheme,
            icon: Icon(
              isLightTheme ? Icons.dark_mode : Icons.light_mode,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newSheet,
        label: const Text('Nueva'),
        icon: const Icon(Icons.add),
      )
          .animate()
          .fadeIn(duration: 260.ms, delay: 100.ms)
          .scale(
        begin: const Offset(0.9, 0.9),
        curve: Curves.easeOutBack,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: LayoutBuilder(
              builder: (context, cons) {
                final maxW = cons.maxWidth.isFinite
                    ? cons.maxWidth
                    : MediaQuery.of(context).size.width;
                final columns = maxW >= 1220
                    ? 3
                    : maxW >= 900
                    ? 2
                    : 1;

                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                  },
                  child: ListView(
                    padding:
                    const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      _HeroHeader(onNew: _newSheet)
                          .animate()
                          .fadeIn(duration: 280.ms)
                          .move(begin: const Offset(0, 12)),
                      const SizedBox(height: 12),
                      _KpiRow(
                        total: s.total,
                        today: s.today,
                        totalRows: s.totalRows,
                      )
                          .animate()
                          .fadeIn(
                        duration: 260.ms,
                        delay: 40.ms,
                      )
                          .move(begin: const Offset(0, 10)),
                      const SizedBox(height: 12),
                      _SearchBar(
                        onChanged: (v) => setState(() => _q = v),
                      )
                          .animate()
                          .fadeIn(
                        duration: 240.ms,
                        delay: 70.ms,
                      )
                          .move(begin: const Offset(0, 8)),
                      const SizedBox(height: 8),
                      if (_items.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            data.length == _items.length
                                ? 'Mostrando ${data.length} planillas'
                                : 'Mostrando ${data.length} de ${_items.length} planillas',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (data.isEmpty)
                        _EmptyState(onNew: _newSheet)
                            .animate()
                            .fadeIn(
                          duration: 240.ms,
                          delay: 100.ms,
                        )
                      else
                        AnimatedSwitcher(
                          duration:
                          const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: _view == _ViewMode.list
                              ? Column(
                            key: const ValueKey('list'),
                            children: [
                              for (int i = 0;
                              i < data.length;
                              i++)
                                _SheetListTile(
                                  meta: data[i],
                                  fmt: _fmt,
                                  onOpen: _open,
                                  onExport: _exportSheet,
                                  onRename: _rename,
                                  onDelete: (m) {
                                    SheetStore.delete(m.id);
                                    _reload();
                                  },
                                )
                                    .animate(
                                  delay:
                                  (80 + i * 30).ms,
                                )
                                    .fadeIn(
                                  duration: 220.ms,
                                )
                                    .move(
                                  begin: const Offset(
                                      0, 8),
                                  curve:
                                  Curves.easeOut,
                                ),
                            ],
                          )
                              : _SheetGrid(
                            key: const ValueKey('grid'),
                            columns: columns,
                            items: data,
                            fmt: _fmt,
                            onOpen: _open,
                            onExport: _exportSheet,
                            onRename: _rename,
                            onDelete: (m) {
                              SheetStore.delete(m.id);
                              _reload();
                            },
                          )
                              .animate()
                              .fadeIn(
                            duration: 220.ms,
                            delay: 80.ms,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Widgets de pantalla ----------

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    final gradient = LinearGradient(
      colors: [
        c.primary,
        c.secondary,
        c.tertiary,
        c.primary,
      ],
      stops: const [0.0, 0.33, 0.66, 1.0],
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: theme.brightness == Brightness.light
            ? gradient
            : LinearGradient(
          colors: [
            c.primary.withValues(alpha: 0.35),
            c.secondary.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: theme.colorScheme.surface.withValues(
            alpha:
            theme.brightness == Brightness.light ? 0.96 : 0.97,
          ),
        ),
        child: LayoutBuilder(
          builder: (_, cons) {
            final stacked = cons.maxWidth < 720;

            final title = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: gradient,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.bolt_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Tus hojas industriales con modo arcoíris',
                      style:
                      theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Planillas estilo Excel con GPS, fotos y XLSX real, listas para campo y para enviar al cliente.',
                  style:
                  theme.textTheme.bodyMedium?.copyWith(
                    color:
                    theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: c.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Atajos, adjuntos y backup JSON incluidos.',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ],
            );

            final button = Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: onNew,
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva planilla'),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: c.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Compatible Android / iOS / Web / Windows',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            );

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 16),
                  button,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 18),
                button,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({
    required this.total,
    required this.today,
    required this.totalRows,
  });

  final int total;
  final int today;
  final int totalRows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    Widget kpi(String title, String value, IconData icon) =>
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: c.surfaceContainerHighest,
            boxShadow: kElevationToShadow[1],
          ),
          child: Column(
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(18),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      c.primary,
                      c.secondary,
                      c.tertiary,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            c.primary.withValues(alpha: 0.18),
                            c.secondary.withValues(alpha: 0.18),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, color: c.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            style: theme.textTheme.titleLarge
                                ?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

    return LayoutBuilder(
      builder: (_, cons) {
        final w = cons.maxWidth;
        final cols =
        w >= 1100 ? 3 : w >= 720 ? 3 : 1;

        final children = <Widget>[
          kpi('Total planillas', '$total',
              Icons.folder_open_rounded),
          kpi('Actualizadas hoy', '$today',
              Icons.bolt_rounded),
          kpi('Filas totales', '$totalRows',
              Icons.table_rows_rounded),
        ];

        if (cols == 1) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom:
                    i == children.length - 1 ? 0 : 10,
                  ),
                  child: children[i],
                ),
            ],
          );
        }

        return GridView.count(
          shrinkWrap: true,
          crossAxisCount: cols,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          physics:
          const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.7,
          children: children,
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar planilla…',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: c.surfaceContainerHighest,
            border: Border.all(color: c.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_rounded,
                size: 18,
                color: c.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Organizá por título o fecha desde arriba',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.45),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      c.primary.withValues(alpha: 0.20),
                      c.secondary.withValues(alpha: 0.20),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.inbox_rounded, size: 42),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'No hay planillas',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Creá tu primera hoja y empezá a medir, auditar o inventariar.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: const Text('Nueva planilla'),
          ),
        ],
      ),
    );
  }
}

class _SheetListTile extends StatelessWidget {
  const _SheetListTile({
    required this.meta,
    required this.fmt,
    required this.onOpen,
    required this.onExport,
    required this.onRename,
    required this.onDelete,
  });

  final SheetMeta meta;
  final String Function(DateTime) fmt;
  final Future<void> Function(SheetMeta) onOpen;
  final Future<void> Function(SheetMeta) onExport;
  final Future<void> Function(SheetMeta) onRename;
  final void Function(SheetMeta) onDelete;

  bool get _recent {
    final now = DateTime.now();
    final d = meta.updatedAt.toLocal();
    final diff = now.difference(d);
    return diff.inHours < 12;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => onOpen(meta),
        onLongPress: () => onRename(meta),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 76,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.primary,
                    c.secondary,
                    c.tertiary,
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: c.primary.withValues(alpha: 0.08),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.description_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  meta.title.isEmpty
                                      ? 'Planilla sin título'
                                      : meta.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_recent)
                                Container(
                                  margin:
                                  const EdgeInsets.only(left: 6),
                                  padding:
                                  const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius:
                                    BorderRadius.circular(
                                        999),
                                    color: c.primary
                                        .withValues(alpha: 0.12),
                                  ),
                                  child: Text(
                                    'Hoy',
                                    style: theme
                                        .textTheme.labelSmall
                                        ?.copyWith(
                                      color: c.primary,
                                      fontWeight:
                                      FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${meta.rows} filas · ${fmt(meta.updatedAt)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Exportar XLSX',
                      onPressed: () => onExport(meta),
                      icon: const Icon(Icons.table_view),
                    ),
                    IconButton(
                      tooltip: 'Renombrar',
                      onPressed: () => onRename(meta),
                      icon: const Icon(Icons.edit_note),
                    ),
                    IconButton(
                      tooltip: 'Abrir',
                      onPressed: () => onOpen(meta),
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                    _DeleteButton(
                      meta: meta,
                      onDelete: onDelete,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.meta,
    required this.onDelete,
  });

  final SheetMeta meta;
  final void Function(SheetMeta) onDelete;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Eliminar',
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => const AlertDialog(
            title: Text('Eliminar'),
            content: Text(
              '¿Eliminar esta planilla? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: null,
                child: Text('Cancelar'),
              ),
              FilledButton(
                onPressed: null,
                child: Text('Eliminar'),
              ),
            ],
          ),
        );
        if (ok == true) {
          onDelete(meta);
        }
      },
      icon: const Icon(Icons.delete_outline),
    );
  }
}

class _SheetGrid extends StatelessWidget {
  const _SheetGrid({
    super.key,
    required this.columns,
    required this.items,
    required this.fmt,
    required this.onOpen,
    required this.onExport,
    required this.onRename,
    required this.onDelete,
  });

  final int columns;
  final List<SheetMeta> items;
  final String Function(DateTime) fmt;
  final Future<void> Function(SheetMeta) onOpen;
  final Future<void> Function(SheetMeta) onExport;
  final Future<void> Function(SheetMeta) onRename;
  final void Function(SheetMeta) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate:
      SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (_, i) {
        final m = items[i];

        return Container(
          decoration: BoxDecoration(
            color: c.surfaceContainerHighest,
            border:
            Border.all(color: c.outlineVariant),
            borderRadius: BorderRadius.circular(18),
            boxShadow: kElevationToShadow[1],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius:
                      BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          c.primary,
                          c.secondary,
                          c.tertiary,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      m.title.isEmpty
                          ? 'Planilla sin título'
                          : m.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${m.rows} filas · ${fmt(m.updatedAt)}',
                style: theme.textTheme.bodySmall,
              ),
              const Spacer(),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => onOpen(m),
                    icon: const Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                    ),
                    label: const Text('Abrir'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Exportar XLSX',
                    onPressed: () => onExport(m),
                    icon: const Icon(Icons.table_view),
                  ),
                  IconButton(
                    tooltip: 'Renombrar',
                    onPressed: () => onRename(m),
                    icon: const Icon(Icons.edit_note),
                  ),
                  const Spacer(),
                  _DeleteButton(
                    meta: m,
                    onDelete: onDelete,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Menú y utilidades ----------

class _SortMenu extends StatelessWidget {
  const _SortMenu({
    required this.current,
    required this.onChanged,
  });

  final _SortMode current;
  final ValueChanged<_SortMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortMode>(
      tooltip: 'Ordenar',
      initialValue: current,
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem<_SortMode>(
          value: _SortMode.updatedDesc,
          child: Text('Recientes'),
        ),
        PopupMenuItem<_SortMode>(
          value: _SortMode.titleAsc,
          child: Text('Título (A–Z)'),
        ),
        PopupMenuItem<_SortMode>(
          value: _SortMode.rowsDesc,
          child: Text('Más filas'),
        ),
      ],
      icon: const Icon(Icons.sort_rounded),
    );
  }
}

class _NoAnimRoute extends PageRouteBuilder<void> {
  _NoAnimRoute({required Widget child})
      : super(
    pageBuilder: (_, __, ___) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}
