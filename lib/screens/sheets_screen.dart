// lib/screens/sheets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/build_info.dart';
import '../services/sheet_store.dart';
import '../ui/ui.dart';
import 'about_screen.dart';
import 'diagnostics_screen.dart';
import 'editor_screen.dart';
import 'privacy_screen.dart';
import 'terms_screen.dart';

enum _SheetAction { open, pinToggle, rename, delete }

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _NewSheetIntent extends Intent {
  const _NewSheetIntent();
}

class _TemplatesIntent extends Intent {
  const _TemplatesIntent();
}

class _OpenLastIntent extends Intent {
  const _OpenLastIntent();
}

class _ClearSearchIntent extends Intent {
  const _ClearSearchIntent();
}

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
  static const double _kMaxWidth = 940;
  static const String _kPinnedKey = 'bitflow_pinned_sheet_ids_v1';

  List<SheetMeta> _items = <SheetMeta>[];
  bool _loading = true;

  final TextEditingController _searchEC = TextEditingController();
  final FocusNode _searchFN = FocusNode(debugLabel: 'sheets_search');
  String _query = '';

  Set<String> _pinnedIds = <String>{};
  bool _pinsLoaded = false;

  void _hapticSelect() {
    AppHaptics.selection();
  }

  void _hapticLight() {
    AppHaptics.light();
  }

  @override
  void initState() {
    super.initState();
    _searchEC.addListener(_onSearchChanged);
    _init();
  }

  @override
  void dispose() {
    _searchEC.removeListener(_onSearchChanged);
    _searchEC.dispose();
    _searchFN.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadPinnedIds();
    _loadSheets();
  }

  Future<void> _loadPinnedIds() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList(_kPinnedKey) ?? <String>[];
      if (!mounted) return;
      setState(() {
        _pinnedIds = list.where((e) => e.trim().isNotEmpty).toSet();
        _pinsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pinnedIds = <String>{};
        _pinsLoaded = true;
      });
    }
  }

  Future<void> _savePinnedIds() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_kPinnedKey, _pinnedIds.toList()..sort());
    } catch (_) {
      // Silencioso: si falla persistencia, no rompemos UX.
    }
  }

  void _togglePinned(String id) {
    final next = Set<String>.from(_pinnedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    setState(() => _pinnedIds = next);
    _hapticSelect();
    _savePinnedIds();
  }

  void _removePinnedIfNeeded(String id) {
    if (!_pinnedIds.contains(id)) return;
    final next = Set<String>.from(_pinnedIds)..remove(id);
    setState(() => _pinnedIds = next);
    _savePinnedIds();
  }

  void _onSearchChanged() {
    final next = _searchEC.text.trim();
    if (next == _query) return;
    setState(() => _query = next);
  }

  void _loadSheets() {
    final list = List<SheetMeta>.from(SheetStore.list());
    list.sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt)); // más reciente arriba
    setState(() {
      _items = list;
      _loading = false;
    });

    // Limpieza: si borraron planillas, eliminamos pins huérfanos.
    if (_pinsLoaded) {
      final ids = list.map((e) => e.id).toSet();
      final orphan = _pinnedIds.where((id) => !ids.contains(id)).toList();
      if (orphan.isNotEmpty) {
        final next = Set<String>.from(_pinnedIds)..removeAll(orphan);
        setState(() => _pinnedIds = next);
        _savePinnedIds();
      }
    }
  }

  Future<void> _handleRefresh() async => _loadSheets();

  Future<bool> _flushSheetStoreOrNotify() async {
    try {
      await SheetStore.flushPendingWrites();
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el cambio local: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  List<SheetMeta> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((it) {
      final title = it.title.toLowerCase();
      final id = it.id.toLowerCase();
      return title.contains(q) || id.contains(q);
    }).toList(growable: false);
  }

  SheetMeta? get _lastUpdatedSheet => _items.isEmpty ? null : _items.first;

  void _focusSearch() {
    if (!mounted) return;
    _searchFN.requestFocus();
    final t = _searchEC.text;
    _searchEC.selection = TextSelection(baseOffset: 0, extentOffset: t.length);
    _hapticSelect();
  }

  void _clearSearch() {
    if (_searchEC.text.isEmpty) return;
    _searchEC.clear();
    _hapticSelect();
  }

  Future<void> _open(String id) async {
    _hapticSelect();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => EditorScreen(
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
          sheetId: id,
        ),
      ),
    );
    if (!mounted) return;
    _loadSheets();
  }

  Future<void> _openLastSheet() async {
    final last = _lastUpdatedSheet;
    if (last == null) return;
    await _open(last.id);
  }

  Future<void> _openStaticPage(Widget page) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  Future<void> _openInfoMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Acerca de'),
                onTap: () => Navigator.of(ctx).pop('about'),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacidad'),
                onTap: () => Navigator.of(ctx).pop('privacy'),
              ),
              ListTile(
                leading: const Icon(Icons.gavel_rounded),
                title: const Text('Terminos'),
                onTap: () => Navigator.of(ctx).pop('terms'),
              ),
              ListTile(
                leading: const Icon(Icons.support_agent_rounded),
                title: const Text('Diagnóstico / Soporte'),
                onTap: () => Navigator.of(ctx).pop('diagnostics'),
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Licencias'),
                onTap: () => Navigator.of(ctx).pop('licenses'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'about':
        await _openStaticPage(const AboutScreen());
        break;
      case 'privacy':
        await _openStaticPage(const PrivacyScreen());
        break;
      case 'terms':
        await _openStaticPage(const TermsScreen());
        break;
      case 'diagnostics':
        await _openStaticPage(DiagnosticsScreen());
        break;
      case 'licenses':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => LicensePage(
              applicationName: 'BitFlow',
              applicationVersion: BuildInfo.stamp,
            ),
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _newBlank() async {
    _hapticLight();
    final id = SheetStore.createNew();
    if (!await _flushSheetStoreOrNotify()) return;
    if (!mounted) return;
    await _open(id);
  }

  Future<void> _newFromTemplate(TemplateKind kind) async {
    _hapticLight();
    final id = SheetStore.createFromTemplate(kind);
    if (!await _flushSheetStoreOrNotify()) return;
    if (!mounted) return;
    await _open(id);
  }

  Future<void> _pickTemplate() async {
    final kind = await showModalBottomSheet<TemplateKind>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final divider = theme.dividerColor.withOpacity(0.65);
        final cardBg = theme.cardColor;

        Widget tile({
          required IconData icon,
          required String title,
          required String subtitle,
          required TemplateKind value,
        }) {
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(ctx).pop(value),
            child: Ink(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: divider, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PillIcon(icon: icon),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Text(
                    'Galeria de templates',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.18,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              children: [
                tile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Plantilla base',
                  subtitle: 'Actividad, Detalle, Estado, Responsable, Fecha',
                  value: TemplateKind.plantilla,
                ),
                tile(
                  icon: Icons.table_rows,
                  title: 'Relevamiento resistividades',
                  subtitle: 'Fecha, Progresiva, 1m, 3m, 5m, Observaciones',
                  value: TemplateKind.resistividades,
                ),
                tile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Inventario simple',
                  subtitle: 'Item, Cantidad, Unidad, Ubicacion, Nota',
                  value: TemplateKind.inventario,
                ),
                tile(
                  icon: Icons.check_circle_outline,
                  title: 'Checklist diario',
                  subtitle: 'Tarea, Responsable, Estado, Fecha, Comentario',
                  value: TemplateKind.checklist,
                ),
              ],
            ),
          ],
        );
      },
    );

    if (!mounted || kind == null) return;
    await _newFromTemplate(kind);
  }

  Future<void> _renameSheet(SheetMeta it) async {
    final controller = TextEditingController(text: it.title);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.renameSheetTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: AppStrings.renameSheetNameLabel,
            hintText: AppStrings.renameSheetNameHint,
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );

    controller.dispose();

    if (!mounted || result == null) return;
    final newTitle = result.trim();
    if (newTitle.isEmpty) return;

    SheetStore.rename(it.id, newTitle);
    if (!await _flushSheetStoreOrNotify()) return;
    _loadSheets();
    _hapticSelect();
  }

  Future<void> _deleteWithConfirm(SheetMeta it) async {
    final title = it.title.isNotEmpty ? it.title : 'Planilla ${it.id}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteSheetTitle),
        content: Text(AppStrings.deleteSheetMessage(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );

    if (!mounted || ok != true) return;

    SheetStore.delete(it.id);
    if (!await _flushSheetStoreOrNotify()) return;
    if (!mounted) return;
    _removePinnedIfNeeded(it.id);
    _loadSheets();

    _hapticLight();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.deletedSheetToast),
        duration: Duration(milliseconds: 1400),
      ),
    );
  }

  Future<void> _showSheetActions(SheetMeta it) async {
    final pinned = _pinnedIds.contains(it.id);
    final action = await showModalBottomSheet<_SheetAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final divider = theme.dividerColor.withOpacity(0.55);
        final title = it.title.isNotEmpty ? it.title : 'Planilla ${it.id}';

        Widget actionTile({
          required IconData icon,
          required String label,
          required _SheetAction value,
          Color? iconColor,
        }) {
          return ListTile(
            leading: _PillIcon(icon: icon, color: iconColor),
            title: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.of(ctx).pop(value),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            actionTile(
              icon: Icons.open_in_new,
              label: AppStrings.open,
              value: _SheetAction.open,
            ),
            Divider(height: 1, thickness: 0.8, color: divider),
            actionTile(
              icon: pinned ? Icons.star_rounded : Icons.star_outline_rounded,
              label: pinned ? 'Desfijar' : 'Fijar',
              value: _SheetAction.pinToggle,
            ),
            Divider(height: 1, thickness: 0.8, color: divider),
            actionTile(
              icon: Icons.edit_outlined,
              label: AppStrings.rename,
              value: _SheetAction.rename,
            ),
            Divider(height: 1, thickness: 0.8, color: divider),
            actionTile(
              icon: Icons.delete_outline,
              label: AppStrings.delete,
              value: _SheetAction.delete,
              iconColor: theme.colorScheme.error,
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );

    if (!mounted || action == null) return;
    await _runAction(it, action);
  }

  Future<void> _showContextMenu(SheetMeta it, Offset globalPos) async {
    final pinned = _pinnedIds.contains(it.id);

    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final rect = overlay == null
        ? RelativeRect.fromLTRB(globalPos.dx, globalPos.dy, 0, 0)
        : RelativeRect.fromRect(
            Rect.fromLTWH(globalPos.dx, globalPos.dy, 1, 1),
            Offset.zero & overlay.size,
          );

    final action = await showMenu<_SheetAction>(
      context: context,
      position: rect,
      items: [
        const PopupMenuItem(
            value: _SheetAction.open, child: Text(AppStrings.open)),
        PopupMenuItem(
          value: _SheetAction.pinToggle,
          child: Text(pinned ? 'Desfijar' : 'Fijar'),
        ),
        const PopupMenuItem(
            value: _SheetAction.rename, child: Text(AppStrings.rename)),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: _SheetAction.delete, child: Text(AppStrings.delete)),
      ],
    );

    if (!mounted || action == null) return;
    await _runAction(it, action);
  }

  Future<void> _runAction(SheetMeta it, _SheetAction action) async {
    switch (action) {
      case _SheetAction.open:
        await _open(it.id);
        break;
      case _SheetAction.pinToggle:
        _togglePinned(it.id);
        break;
      case _SheetAction.rename:
        await _renameSheet(it);
        break;
      case _SheetAction.delete:
        await _deleteWithConfirm(it);
        break;
    }
  }

  String _formatUpdatedAt(DateTime d) {
    final local = d.toLocal();
    final now = DateTime.now();

    String hhmm(DateTime x) =>
        '${x.hour.toString().padLeft(2, '0')}:${x.minute.toString().padLeft(2, '0')}';

    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    if (sameDay) return 'Hoy ${hhmm(local)}';

    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    return '$dd/$mm ${hhmm(local)}';
  }

  String get _subtitleText {
    if (_loading) return 'Cargando planillas...';
    if (_items.isEmpty) return 'Sin planillas guardadas todavia';

    final last = _lastUpdatedSheet;
    final lastLabel = last != null ? _formatUpdatedAt(last.updatedAt) : '—';
    final pins = _pinnedIds.length;

    // Apple-like: informativo pero sin ruido.
    if (pins > 0) {
      return '${_items.length} planillas · $pins fijadas · Última: $lastLabel';
    }
    return '${_items.length} planillas · Última: $lastLabel';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: const LoadingState(message: 'Cargando planillas...'),
            ),
          ),
        ),
      );
    }

    final filtered = _filtered;

    final pinned = <SheetMeta>[];
    final others = <SheetMeta>[];

    for (final it in filtered) {
      if (_pinnedIds.contains(it.id)) {
        pinned.add(it);
      } else {
        others.add(it);
      }
    }

    // (Redundante si _items ya viene ordenado por updatedAt, pero seguro)
    pinned.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    others.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final hasAny = _items.isNotEmpty;
    final hasAnyFiltered = filtered.isNotEmpty;
    final noResults = hasAny && !hasAnyFiltered && _query.isNotEmpty;
    final canOpenLast = _lastUpdatedSheet != null;

    // No robamos Ctrl/Cmd+F. Usamos K y /.
    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          const _FocusSearchIntent(),
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
          const _FocusSearchIntent(),
      const SingleActivator(LogicalKeyboardKey.slash):
          const _FocusSearchIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          const _NewSheetIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          const _NewSheetIntent(),
      const SingleActivator(LogicalKeyboardKey.keyT, control: true):
          const _TemplatesIntent(),
      const SingleActivator(LogicalKeyboardKey.keyT, meta: true):
          const _TemplatesIntent(),
      const SingleActivator(LogicalKeyboardKey.keyL, control: true):
          const _OpenLastIntent(),
      const SingleActivator(LogicalKeyboardKey.keyL, meta: true):
          const _OpenLastIntent(),
      const SingleActivator(LogicalKeyboardKey.escape):
          const _ClearSearchIntent(),
    };

    final appearanceKey = Object.hash(
      theme.brightness,
      theme.scaffoldBackgroundColor.value,
      theme.dividerColor.value,
      theme.colorScheme.surfaceVariant.value,
    );

    SliverToBoxAdapter sectionHeader(String label, {int? count}) {
      final t = Theme.of(context);
      final text = count == null ? label : '$label · $count';
      return SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Text(
                text,
                style: t.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                  color: t.colorScheme.onSurface.withOpacity(0.70),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(onInvoke: (_) {
            _focusSearch();
            return null;
          }),
          _NewSheetIntent: CallbackAction<_NewSheetIntent>(onInvoke: (_) {
            _newBlank();
            return null;
          }),
          _TemplatesIntent: CallbackAction<_TemplatesIntent>(onInvoke: (_) {
            _pickTemplate();
            return null;
          }),
          _OpenLastIntent: CallbackAction<_OpenLastIntent>(onInvoke: (_) {
            if (canOpenLast) _openLastSheet();
            return null;
          }),
          _ClearSearchIntent: CallbackAction<_ClearSearchIntent>(onInvoke: (_) {
            _clearSearch();
            FocusManager.instance.primaryFocus?.unfocus();
            return null;
          }),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _AppleLargeTitleAppBar(
                    title: AppStrings.sheetsTitle,
                    subtitle: _subtitleText,
                    onNew: _newBlank,
                    onTemplates: _pickTemplate,
                    onToggleTheme: widget.onToggleTheme,
                    onMoreInfo: _openInfoMenu,
                    isLight: widget.isLight,
                    hapticSelect: _hapticSelect,
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SearchHeaderDelegate(
                      height: 126,
                      controller: _searchEC,
                      focusNode: _searchFN,
                      onNew: _newBlank,
                      onTemplates: _pickTemplate,
                      onOpenLast: canOpenLast ? _openLastSheet : null,
                      appearanceKey: appearanceKey,
                      hapticSelect: _hapticSelect,
                    ),
                  ),
                  if (!hasAny)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _Empty(
                        onNew: _newBlank,
                        onTemplates: _pickTemplate,
                      ),
                    )
                  else if (noResults)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _NoResults(
                        query: _query,
                        onClear: _clearSearch,
                      ),
                    )
                  else ...[
                    if (pinned.isNotEmpty) ...[
                      sectionHeader('Fijadas', count: pinned.length),
                      _SheetsSliverList(
                        items: pinned,
                        formatUpdatedAt: _formatUpdatedAt,
                        onOpen: (id) => _open(id),
                        onActions: (it) => _showSheetActions(it),
                        onContextMenu: (it, pos) => _showContextMenu(it, pos),
                        isPinned: (id) => _pinnedIds.contains(id),
                        onTogglePinned: (id) => _togglePinned(id),
                        hapticSelect: _hapticSelect,
                      ),
                    ],
                    if (others.isNotEmpty) ...[
                      sectionHeader(
                          pinned.isNotEmpty ? 'Recientes' : 'Planillas',
                          count: others.length),
                      _SheetsSliverList(
                        items: others,
                        formatUpdatedAt: _formatUpdatedAt,
                        onOpen: (id) => _open(id),
                        onActions: (it) => _showSheetActions(it),
                        onContextMenu: (it, pos) => _showContextMenu(it, pos),
                        isPinned: (id) => _pinnedIds.contains(id),
                        onTogglePinned: (id) => _togglePinned(id),
                        hapticSelect: _hapticSelect,
                        bottomPadding: 110,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetsSliverList extends StatelessWidget {
  const _SheetsSliverList({
    required this.items,
    required this.formatUpdatedAt,
    required this.onOpen,
    required this.onActions,
    required this.onContextMenu,
    required this.isPinned,
    required this.onTogglePinned,
    required this.hapticSelect,
    this.bottomPadding = 22,
  });

  final List<SheetMeta> items;
  final String Function(DateTime) formatUpdatedAt;
  final Future<void> Function(String) onOpen;
  final Future<void> Function(SheetMeta) onActions;
  final Future<void> Function(SheetMeta, Offset) onContextMenu;
  final bool Function(String) isPinned;
  final void Function(String) onTogglePinned;
  final VoidCallback hapticSelect;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(12, 6, 12, bottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) {
            final it = items[i];
            final updated = formatUpdatedAt(it.updatedAt);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 940),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SheetCard(
                    meta: it,
                    updatedLabel: updated,
                    accent: theme.colorScheme.primary,
                    pinned: isPinned(it.id),
                    onTogglePinned: () => onTogglePinned(it.id),
                    onOpen: () => onOpen(it.id),
                    onActions: () => onActions(it),
                    onContextMenu: (pos) => onContextMenu(it, pos),
                    hapticSelect: hapticSelect,
                  ),
                ),
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }
}

class _AppleLargeTitleAppBar extends StatelessWidget {
  const _AppleLargeTitleAppBar({
    required this.title,
    required this.subtitle,
    required this.onNew,
    required this.onTemplates,
    required this.onToggleTheme,
    required this.onMoreInfo,
    required this.isLight,
    required this.hapticSelect,
  });

  final String title;
  final String subtitle;
  final VoidCallback onNew;
  final VoidCallback onTemplates;
  final VoidCallback onToggleTheme;
  final VoidCallback onMoreInfo;
  final bool isLight;
  final VoidCallback hapticSelect;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: AppTopBar(
              title: title,
              subtitle: subtitle,
              actions: [
                AppButton(
                  label: AppStrings.newSheet,
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  onPressed: () {
                    hapticSelect();
                    onNew();
                  },
                ),
                AppButton(
                  label: AppStrings.templates,
                  icon: Icons.view_quilt_outlined,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  onPressed: () {
                    hapticSelect();
                    onTemplates();
                  },
                ),
                AppButton(
                  label: isLight ? 'Noche' : 'Día',
                  icon: isLight
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  onPressed: () {
                    hapticSelect();
                    onToggleTheme();
                  },
                ),
                AppButton(
                  label: AppStrings.actions,
                  icon: Icons.more_horiz_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  onPressed: () {
                    hapticSelect();
                    onMoreInfo();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  _SearchHeaderDelegate({
    required this.height,
    required this.controller,
    required this.focusNode,
    required this.onNew,
    required this.onTemplates,
    required this.onOpenLast,
    required this.appearanceKey,
    required this.hapticSelect,
  });

  final double height;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onNew;
  final VoidCallback onTemplates;
  final VoidCallback? onOpenLast;
  final int appearanceKey;
  final VoidCallback hapticSelect;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final bg = theme.scaffoldBackgroundColor.withOpacity(0.92);
    final divider = theme.dividerColor.withOpacity(0.55);
    final canOpenLast = onOpenLast != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: divider, width: 0.8)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                _SearchBar(
                  controller: controller,
                  focusNode: focusNode,
                  hint: AppStrings.sheetsSearchHint,
                  onClearHaptic: hapticSelect,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        Semantics(
                          button: true,
                          label: AppStrings.semAddSheet,
                          child: FilledButton.icon(
                            onPressed: onNew,
                            icon: const Icon(Icons.add),
                            label: const Text(AppStrings.newSheet),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Semantics(
                          button: true,
                          label: AppStrings.semTemplates,
                          child: OutlinedButton.icon(
                            onPressed: onTemplates,
                            icon: const Icon(Icons.view_quilt_outlined),
                            label: const Text(AppStrings.templates),
                          ),
                        ),
                        if (canOpenLast) ...[
                          const SizedBox(width: 10),
                          Semantics(
                            button: true,
                            label: AppStrings.semOpenLastSheet,
                            child: OutlinedButton.icon(
                              onPressed: onOpenLast,
                              icon: const Icon(Icons.history_toggle_off),
                              label: const Text(AppStrings.openLast),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate old) {
    return old.height != height ||
        old.controller != controller ||
        old.focusNode != focusNode ||
        old.onOpenLast != onOpenLast ||
        old.appearanceKey != appearanceKey;
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onClearHaptic,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final VoidCallback onClearHaptic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Semantics(
          textField: true,
          label: 'Buscar planillas',
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: AppStrings.clearSearch,
                      onPressed: () {
                        controller.clear();
                        onClearHaptic();
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }
}

class _SheetCard extends StatefulWidget {
  const _SheetCard({
    required this.meta,
    required this.updatedLabel,
    required this.onOpen,
    required this.onActions,
    required this.onContextMenu,
    required this.accent,
    required this.pinned,
    required this.onTogglePinned,
    required this.hapticSelect,
  });

  final SheetMeta meta;
  final String updatedLabel;
  final VoidCallback onOpen;
  final VoidCallback onActions;
  final ValueChanged<Offset> onContextMenu;
  final Color accent;
  final bool pinned;
  final VoidCallback onTogglePinned;
  final VoidCallback hapticSelect;

  @override
  State<_SheetCard> createState() => _SheetCardState();
}

class _SheetCardState extends State<_SheetCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title = widget.meta.title.isNotEmpty
        ? widget.meta.title
        : 'Planilla ${widget.meta.id}';
    final details =
        'Actualizada: ${widget.updatedLabel} · Filas: ${widget.meta.rows}';

    return AnimatedScale(
      scale: _pressed ? 0.988 : 1.0,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      child: Material(
        color: theme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: theme.dividerColor.withOpacity(0.60),
            width: 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          label: 'Abrir planilla $title',
          child: InkWell(
            onTap: widget.onOpen,
            onLongPress: widget.onActions,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            onSecondaryTapDown: (d) => widget.onContextMenu(d.globalPosition),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  _PillIcon(
                    icon: Icons.table_chart,
                    color: widget.accent,
                    filled: true,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.appText.titleMedium,
                              ),
                            ),
                            if (widget.pinned) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.star_rounded,
                                size: 18,
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.65),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appText.bodyMuted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PillButton(
                    tooltip: widget.pinned ? 'Desfijar' : 'Fijar',
                    semanticsLabel: AppStrings.semTogglePin,
                    icon: widget.pinned
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    onTap: () {
                      widget.hapticSelect();
                      widget.onTogglePinned();
                    },
                  ),
                  const SizedBox(width: 8),
                  _PillButton(
                    tooltip: AppStrings.actions,
                    semanticsLabel: AppStrings.semOpenSheetActions,
                    icon: Icons.more_horiz,
                    onTap: () {
                      widget.hapticSelect();
                      widget.onActions();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  const _PillButton({
    required this.tooltip,
    required this.semanticsLabel,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final String semanticsLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bg = theme.colorScheme.surfaceVariant.withOpacity(
      theme.brightness == Brightness.dark ? 0.55 : 0.70,
    );

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: bg,
        shape: const StadiumBorder(),
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const StadiumBorder(),
          onHighlightChanged: (v) => setState(() => _pressed = v),
          child: Semantics(
            button: true,
            label: widget.semanticsLabel,
            child: Tooltip(
              message: widget.tooltip,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Icon(widget.icon, size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillIcon extends StatelessWidget {
  const _PillIcon({
    required this.icon,
    this.color,
    this.filled = false,
  });

  final IconData icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;

    final bg = filled
        ? c.withOpacity(theme.brightness == Brightness.dark ? 0.22 : 0.14)
        : theme.colorScheme.surfaceVariant.withOpacity(
            theme.brightness == Brightness.dark ? 0.55 : 0.70,
          );

    return Container(
      width: 42,
      height: 42,
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: bg,
      ),
      child: Icon(icon, color: c, size: 20),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyState(
                title: AppStrings.emptySheetsTitle,
                message: AppStrings.emptySheetsBody,
                icon: Icons.table_chart_outlined,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Semantics(
                    button: true,
                    label: AppStrings.semAddSheet,
                    child: AppButton(
                      label: AppStrings.newSheet,
                      icon: Icons.add,
                      variant: AppButtonVariant.primary,
                      onPressed: onNew,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: AppStrings.semTemplates,
                    child: AppButton(
                      label: AppStrings.templates,
                      icon: Icons.view_quilt_outlined,
                      variant: AppButtonVariant.secondary,
                      onPressed: onTemplates,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({
    required this.query,
    required this.onClear,
  });

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: EmptyState(
            title: AppStrings.noResultsTitle,
            message: AppStrings.noResultsBody(query),
            icon: Icons.search_off_outlined,
            actionLabel: AppStrings.clearSearch,
            onAction: onClear,
          ),
        ),
      ),
    );
  }
}
