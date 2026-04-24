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
      (a, b) => b.updatedAt.compareTo(a.updatedAt),
    ); // más reciente arriba
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
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _openInfoMenu() async {
    final t = context.tokens;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(
        alpha: t.colors.isLight ? 0.16 : 0.42,
      ),
      useSafeArea: true,
      builder: (ctx) {
        return _OverlaySheetFrame(
          title: 'BitFlow',
          subtitle: 'Informacion, soporte y detalles legales',
          maxHeightFactor: 0.64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OverlayActionTile(
                icon: Icons.info_outline_rounded,
                label: 'Acerca de',
                subtitle: 'Producto, version y enfoque general',
                onTap: () => Navigator.of(ctx).pop('about'),
              ),
              SizedBox(height: t.spacing.sm),
              _OverlayActionTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacidad',
                subtitle: 'Uso de datos y resguardos',
                onTap: () => Navigator.of(ctx).pop('privacy'),
              ),
              SizedBox(height: t.spacing.sm),
              _OverlayActionTile(
                icon: Icons.gavel_rounded,
                label: 'Terminos',
                subtitle: 'Condiciones y alcance del servicio',
                onTap: () => Navigator.of(ctx).pop('terms'),
              ),
              SizedBox(height: t.spacing.sm),
              _OverlayActionTile(
                icon: Icons.support_agent_rounded,
                label: 'Diagnóstico / Soporte',
                subtitle: 'Estado, logs y ayuda operativa',
                onTap: () => Navigator.of(ctx).pop('diagnostics'),
              ),
              SizedBox(height: t.spacing.sm),
              _OverlayActionTile(
                icon: Icons.article_outlined,
                label: 'Licencias',
                subtitle: 'Paquetes y atribuciones',
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
    final t = context.tokens;
    final kind = await showModalBottomSheet<TemplateKind>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(
        alpha: t.colors.isLight ? 0.16 : 0.42,
      ),
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        return _OverlaySheetFrame(
          title: 'Galeria de templates',
          subtitle: 'Casos tecnicos listos para campo, evidencia y exportacion',
          maxHeightFactor: 0.78,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount =
                  MediaQuery.sizeOf(context).width >= 760 ? 2 : 1;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: t.spacing.sm,
                mainAxisSpacing: t.spacing.sm,
                childAspectRatio: crossAxisCount == 2 ? 1.18 : 1.45,
                children: [
                  _TemplateTile(
                    icon: Icons.bolt_rounded,
                    title: 'Proteccion catodica',
                    subtitle: 'ON/OFF, IR drop, cupon, estado y evidencia',
                    onTap: () =>
                        Navigator.of(ctx).pop(TemplateKind.proteccionCatodica),
                  ),
                  _TemplateTile(
                    icon: Icons.auto_awesome_outlined,
                    title: 'Relevamiento con evidencias',
                    subtitle: 'Cliente, sector, hallazgo, criticidad y accion',
                    onTap: () => Navigator.of(ctx).pop(TemplateKind.plantilla),
                  ),
                  _TemplateTile(
                    icon: Icons.table_rows_rounded,
                    title: 'Puesta a tierra',
                    subtitle: 'PAT, resistencia, continuidad y responsable',
                    onTap: () =>
                        Navigator.of(ctx).pop(TemplateKind.resistividades),
                  ),
                  _TemplateTile(
                    icon: Icons.inventory_2_outlined,
                    title: 'Control operativo',
                    subtitle: 'Equipo, control, valor, estado y accion',
                    onTap: () => Navigator.of(ctx).pop(TemplateKind.inventario),
                  ),
                  _TemplateTile(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Inspeccion de campo',
                    subtitle: 'Frente, actividad, estado y observaciones',
                    onTap: () => Navigator.of(ctx).pop(TemplateKind.checklist),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (!mounted || kind == null) return;
    await _newFromTemplate(kind);
  }

  Future<void> _renameSheet(SheetMeta it) async {
    final controller = TextEditingController(text: it.title);

    final result = await showAppModal<String>(
      context: context,
      title: AppStrings.renameSheetTitle,
      barrierDismissible: true,
      child: AppTextField(
        controller: controller,
        label: AppStrings.renameSheetNameLabel,
        hint: AppStrings.renameSheetNameHint,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton(
          label: AppStrings.save,
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).pop(controller.text),
        ),
      ],
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

    final ok = await showAppModal<bool>(
      context: context,
      title: AppStrings.deleteSheetTitle,
      barrierDismissible: true,
      child: Text(AppStrings.deleteSheetMessage(title)),
      actions: [
        AppButton(
          label: AppStrings.cancel,
          variant: AppButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: AppStrings.delete,
          icon: Icons.delete_outline_rounded,
          variant: AppButtonVariant.destructive,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
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
    final t = context.tokens;
    final action = await showModalBottomSheet<_SheetAction>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(
        alpha: t.colors.isLight ? 0.16 : 0.42,
      ),
      useSafeArea: true,
      builder: (ctx) {
        final title = it.title.isNotEmpty ? it.title : 'Planilla ${it.id}';
        return _OverlaySheetFrame(
          title: title,
          subtitle: 'Acciones rapidas para esta planilla',
          maxHeightFactor: 0.58,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OverlayActionTile(
                icon: Icons.open_in_new_rounded,
                label: AppStrings.open,
                subtitle: 'Entrar al editor y continuar',
                onTap: () => Navigator.of(ctx).pop(_SheetAction.open),
              ),
              SizedBox(height: t.spacing.sm),
              _OverlayActionTile(
                icon: pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                label: pinned ? 'Desfijar' : 'Fijar',
                subtitle: pinned
                    ? 'Quitar acceso rapido de la lista fijada'
                    : 'Mantener visible arriba de la lista',
                tone: _OverlayTone.accent,
                onTap: () => Navigator.of(ctx).pop(_SheetAction.pinToggle),
              ),
              SizedBox(height: t.spacing.sm),
              _OverlayActionTile(
                icon: Icons.edit_outlined,
                label: AppStrings.rename,
                subtitle: 'Actualizar el nombre visible',
                onTap: () => Navigator.of(ctx).pop(_SheetAction.rename),
              ),
              SizedBox(height: t.spacing.sm),
              _OverlayActionTile(
                icon: Icons.delete_outline_rounded,
                label: AppStrings.delete,
                subtitle: 'Eliminar esta planilla local',
                tone: _OverlayTone.danger,
                onTap: () => Navigator.of(ctx).pop(_SheetAction.delete),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    await _runAction(it, action);
  }

  Future<void> _showContextMenu(SheetMeta it, Offset globalPos) async {
    final pinned = _pinnedIds.contains(it.id);
    final t = context.tokens;

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
      color: t.colors.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radii.md),
        side: BorderSide(color: t.colors.border),
      ),
      items: [
        const PopupMenuItem(
          value: _SheetAction.open,
          child: _PopupMenuRow(
            icon: Icons.open_in_new_rounded,
            label: AppStrings.open,
          ),
        ),
        PopupMenuItem(
          value: _SheetAction.pinToggle,
          child: _PopupMenuRow(
            icon: pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            label: pinned ? 'Desfijar' : 'Fijar',
          ),
        ),
        const PopupMenuItem(
          value: _SheetAction.rename,
          child: _PopupMenuRow(
            icon: Icons.edit_outlined,
            label: AppStrings.rename,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _SheetAction.delete,
          child: _PopupMenuRow(
            icon: Icons.delete_outline_rounded,
            label: AppStrings.delete,
            tone: _OverlayTone.danger,
          ),
        ),
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
    final t = context.tokens;

    if (_loading) {
      return Scaffold(
        backgroundColor: t.colors.bg,
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.spacing.xl),
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
      t.colors.bg.toARGB32(),
      t.colors.surface.toARGB32(),
      t.colors.border.toARGB32(),
      t.colors.accent.toARGB32(),
    );

    SliverToBoxAdapter sectionHeader(String label, {int? count}) {
      return SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _kMaxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                t.spacing.lg,
                t.spacing.lg,
                t.spacing.lg,
                t.spacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    label,
                    style: t.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: t.colors.textPrimary,
                    ),
                  ),
                  if (count != null) ...[
                    SizedBox(width: t.spacing.sm),
                    _CountBadge(count: count),
                  ],
                  SizedBox(width: t.spacing.md),
                  Expanded(child: Container(height: 1, color: t.colors.border)),
                ],
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
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _focusSearch();
              return null;
            },
          ),
          _NewSheetIntent: CallbackAction<_NewSheetIntent>(
            onInvoke: (_) {
              _newBlank();
              return null;
            },
          ),
          _TemplatesIntent: CallbackAction<_TemplatesIntent>(
            onInvoke: (_) {
              _pickTemplate();
              return null;
            },
          ),
          _OpenLastIntent: CallbackAction<_OpenLastIntent>(
            onInvoke: (_) {
              if (canOpenLast) _openLastSheet();
              return null;
            },
          ),
          _ClearSearchIntent: CallbackAction<_ClearSearchIntent>(
            onInvoke: (_) {
              _clearSearch();
              FocusManager.instance.primaryFocus?.unfocus();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: t.colors.bg,
            body: RefreshIndicator(
              color: t.colors.accent,
              backgroundColor: t.colors.surfaceElevated,
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
                      height: 160,
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
                      child: _NoResults(query: _query, onClear: _clearSearch),
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
                        count: others.length,
                      ),
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
    final t = context.tokens;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        t.spacing.md,
        t.spacing.xs,
        t.spacing.md,
        bottomPadding,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((ctx, i) {
          final it = items[i];
          final updated = formatUpdatedAt(it.updatedAt);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 940),
              child: Padding(
                padding: EdgeInsets.only(bottom: t.spacing.sm),
                child: _SheetCard(
                  meta: it,
                  updatedLabel: updated,
                  accent: t.colors.accent,
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
        }, childCount: items.length),
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
    final t = context.tokens;
    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              t.spacing.lg,
              t.spacing.lg,
              t.spacing.lg,
              t.spacing.sm,
            ),
            child: AppTopBar(
              title: title,
              subtitle: subtitle,
              actions: [
                AppButton(
                  label: AppStrings.newSheet,
                  icon: Icons.add,
                  variant: AppButtonVariant.primary,
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
                  label: isLight ? 'Noche' : 'Dia',
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
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final t = context.tokens;
    final bg = t.colors.bg.withValues(alpha: 0.94);
    final divider = t.colors.border.withValues(alpha: 0.9);
    final canOpenLast = onOpenLast != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: divider, width: 1)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              t.spacing.md,
              t.spacing.sm,
              t.spacing.md,
              t.spacing.md,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.colors.surface,
                borderRadius: BorderRadius.circular(t.radii.xl),
                border: Border.all(
                  color:
                      overlapsContent ? t.colors.borderStrong : t.colors.border,
                ),
                boxShadow: t.shadows.soft,
              ),
              child: Padding(
                padding: EdgeInsets.all(t.spacing.md),
                child: Column(
                  children: [
                    _SearchBar(
                      controller: controller,
                      focusNode: focusNode,
                      hint: AppStrings.sheetsSearchHint,
                      onClearHaptic: hapticSelect,
                    ),
                    SizedBox(height: t.spacing.sm),
                    SizedBox(
                      height: 36,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            Semantics(
                              button: true,
                              label: AppStrings.semAddSheet,
                              child: AppButton(
                                label: AppStrings.newSheet,
                                icon: Icons.add,
                                variant: AppButtonVariant.primary,
                                size: AppButtonSize.sm,
                                onPressed: onNew,
                              ),
                            ),
                            SizedBox(width: t.spacing.sm),
                            Semantics(
                              button: true,
                              label: AppStrings.semTemplates,
                              child: AppButton(
                                label: AppStrings.templates,
                                icon: Icons.view_quilt_outlined,
                                variant: AppButtonVariant.secondary,
                                size: AppButtonSize.sm,
                                onPressed: onTemplates,
                              ),
                            ),
                            if (canOpenLast) ...[
                              SizedBox(width: t.spacing.sm),
                              Semantics(
                                button: true,
                                label: AppStrings.semOpenLastSheet,
                                child: AppButton(
                                  label: AppStrings.openLast,
                                  icon: Icons.history_toggle_off,
                                  variant: AppButtonVariant.ghost,
                                  size: AppButtonSize.sm,
                                  onPressed: onOpenLast,
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

class _SearchBar extends StatefulWidget {
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
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode == widget.focusNode) return;
    oldWidget.focusNode.removeListener(_handleFocusChanged);
    _focused = widget.focusNode.hasFocus;
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_focused == widget.focusNode.hasFocus) return;
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final highlighted = _focused || value.text.isNotEmpty;
        return Semantics(
          textField: true,
          label: 'Buscar planillas',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _focused ? t.colors.surface : t.colors.surfaceMuted,
              borderRadius: BorderRadius.circular(t.radii.lg),
              border: Border.all(
                color: _focused ? t.colors.accent : t.colors.border,
                width: _focused ? 1.2 : 1,
              ),
              boxShadow: _focused ? t.shadows.soft : const <BoxShadow>[],
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: widget.hint,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: t.spacing.md),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: highlighted ? t.colors.accent : t.colors.textSecondary,
                  size: 20,
                ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: AppStrings.clearSearch,
                        onPressed: () {
                          widget.controller.clear();
                          widget.onClearHaptic();
                        },
                        icon: Icon(
                          Icons.close_rounded,
                          color: t.colors.textSecondary,
                          size: 18,
                        ),
                      ),
              ),
              style: context.appText.bodyStrong.copyWith(
                color: t.colors.textPrimary,
              ),
            ),
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
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isEmphasized = _hovered || _focused;

    final title = widget.meta.title.isNotEmpty
        ? widget.meta.title
        : 'Planilla ${widget.meta.id}';
    final borderColor = _focused
        ? t.colors.accent
        : isEmphasized
            ? t.colors.borderStrong
            : t.colors.border;
    final cardColor = _focused ? t.colors.surfaceElevated : t.colors.surface;
    final shadow = isEmphasized ? t.shadows.card : t.shadows.soft;

    return AnimatedScale(
      scale: _pressed ? 0.988 : 1.0,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(t.radii.lg),
          border: Border.all(color: borderColor, width: _focused ? 1.2 : 1),
          boxShadow: shadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(t.radii.lg),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            button: true,
            label: 'Abrir planilla $title',
            child: InkWell(
              onTap: widget.onOpen,
              onLongPress: widget.onActions,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              onHover: (v) {
                if (_hovered == v) return;
                setState(() => _hovered = v);
              },
              onFocusChange: (v) {
                if (_focused == v) return;
                setState(() => _focused = v);
              },
              onSecondaryTapDown: (d) => widget.onContextMenu(d.globalPosition),
              hoverColor: t.colors.hover,
              splashColor: t.colors.pressed,
              child: Padding(
                padding: EdgeInsets.all(t.spacing.lg),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final actionStrip = ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: compact ? constraints.maxWidth : 290,
                      ),
                      child: Wrap(
                        spacing: t.spacing.sm,
                        runSpacing: t.spacing.sm,
                        alignment:
                            compact ? WrapAlignment.start : WrapAlignment.end,
                        children: [
                          AppButton(
                            label: AppStrings.open,
                            icon: Icons.open_in_new_rounded,
                            variant: AppButtonVariant.primary,
                            size: AppButtonSize.sm,
                            onPressed: () {
                              widget.hapticSelect();
                              widget.onOpen();
                            },
                          ),
                          AppButton(
                            label: widget.pinned ? 'Fijada' : 'Fijar',
                            icon: widget.pinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            variant: widget.pinned
                                ? AppButtonVariant.primary
                                : AppButtonVariant.secondary,
                            size: AppButtonSize.sm,
                            onPressed: () {
                              widget.hapticSelect();
                              widget.onTogglePinned();
                            },
                          ),
                          AppButton(
                            label: AppStrings.actions,
                            icon: Icons.more_horiz_rounded,
                            variant: AppButtonVariant.ghost,
                            size: AppButtonSize.sm,
                            onPressed: () {
                              widget.hapticSelect();
                              widget.onActions();
                            },
                          ),
                        ],
                      ),
                    );

                    final sheetInfo = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PillIcon(
                          icon: Icons.table_chart_rounded,
                          color: widget.accent,
                          filled: true,
                        ),
                        SizedBox(width: t.spacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.appText.titleMedium.copyWith(
                                  color: t.colors.textPrimary,
                                ),
                              ),
                              SizedBox(height: t.spacing.xs),
                              Text(
                                'ID ${widget.meta.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.text.bodySmall?.copyWith(
                                  color: t.colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: t.spacing.sm),
                              Wrap(
                                spacing: t.spacing.sm,
                                runSpacing: t.spacing.sm,
                                children: [
                                  _FactBadge(
                                    icon: Icons.schedule_rounded,
                                    label: 'Ultima',
                                    value: widget.updatedLabel,
                                  ),
                                  _FactBadge(
                                    icon: Icons.view_headline_rounded,
                                    label: 'Filas',
                                    value: '${widget.meta.rows}',
                                  ),
                                  if (widget.pinned)
                                    const _FactBadge(
                                      icon: Icons.push_pin_rounded,
                                      label: 'Estado',
                                      value: 'Fijada',
                                      tone: _BadgeTone.accent,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sheetInfo,
                          SizedBox(height: t.spacing.md),
                          actionStrip,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: sheetInfo),
                        SizedBox(width: t.spacing.lg),
                        actionStrip,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillIcon extends StatelessWidget {
  const _PillIcon({required this.icon, this.color, this.filled = false});

  final IconData icon;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.colors.accent;

    final bg = filled
        ? c.withValues(alpha: t.colors.isLight ? 0.14 : 0.22)
        : t.colors.surfaceMuted;

    return Container(
      width: 42,
      height: 42,
      decoration: ShapeDecoration(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radii.md),
          side: BorderSide(
            color: filled ? c.withValues(alpha: 0.18) : t.colors.border,
          ),
        ),
      ),
      child: Icon(icon, color: c, size: 20),
    );
  }
}

enum _BadgeTone { neutral, accent, danger }

class _FactBadge extends StatelessWidget {
  const _FactBadge({
    required this.label,
    required this.value,
    this.icon,
    this.tone = _BadgeTone.neutral,
  });

  final String label;
  final String value;
  final IconData? icon;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    late final Color bg;
    late final Color border;
    late final Color valueColor;

    switch (tone) {
      case _BadgeTone.accent:
        bg = t.colors.accentMuted;
        border = t.colors.accent.withValues(alpha: 0.18);
        valueColor = t.colors.accent;
        break;
      case _BadgeTone.danger:
        bg = t.colors.dangerBg;
        border = t.colors.dangerFg.withValues(alpha: 0.18);
        valueColor = t.colors.dangerFg;
        break;
      case _BadgeTone.neutral:
        bg = t.colors.surfaceMuted;
        border = t.colors.border;
        valueColor = t.colors.textPrimary;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.sm,
        vertical: t.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(t.radii.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: valueColor),
            SizedBox(width: t.spacing.xs),
          ],
          Text(
            label,
            style: t.text.bodySmall?.copyWith(
              color: t.colors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: t.spacing.xs),
          Text(
            value,
            style: t.text.bodySmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spacing.sm,
        vertical: t.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: t.colors.accentMuted,
        borderRadius: BorderRadius.circular(t.radii.pill),
        border: Border.all(color: t.colors.accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$count',
        style: t.text.bodySmall?.copyWith(
          color: t.colors.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _OverlayTone { neutral, accent, danger }

class _OverlaySheetFrame extends StatelessWidget {
  const _OverlaySheetFrame({
    required this.child,
    this.title,
    this.subtitle,
    this.maxHeightFactor = 0.72,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final double maxHeightFactor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            t.spacing.sm,
            0,
            t.spacing.sm,
            t.spacing.sm,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 760,
              maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.colors.surfaceElevated,
                borderRadius: BorderRadius.circular(t.radii.xl),
                border: Border.all(color: t.colors.border),
                boxShadow: t.shadows.floating,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  t.spacing.lg,
                  t.spacing.sm,
                  t.spacing.lg,
                  t.spacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: t.colors.borderStrong,
                          borderRadius: BorderRadius.circular(t.radii.pill),
                        ),
                      ),
                    ),
                    SizedBox(height: t.spacing.md),
                    if (title != null && title!.trim().isNotEmpty) ...[
                      Text(
                        title!,
                        style: context.appText.titleMedium.copyWith(
                          color: t.colors.textPrimary,
                        ),
                      ),
                    ],
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      SizedBox(height: t.spacing.xs),
                      Text(
                        subtitle!,
                        style: t.text.bodyMedium?.copyWith(
                          color: t.colors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    SizedBox(height: t.spacing.md),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverlayActionTile extends StatelessWidget {
  const _OverlayActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.tone = _OverlayTone.neutral,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final _OverlayTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    late final Color bg;
    late final Color border;
    late final Color iconColor;

    switch (tone) {
      case _OverlayTone.accent:
        bg = t.colors.accentMuted;
        border = t.colors.accent.withValues(alpha: 0.18);
        iconColor = t.colors.accent;
        break;
      case _OverlayTone.danger:
        bg = t.colors.dangerBg;
        border = t.colors.dangerFg.withValues(alpha: 0.18);
        iconColor = t.colors.dangerFg;
        break;
      case _OverlayTone.neutral:
        bg = t.colors.surface;
        border = t.colors.border;
        iconColor = t.colors.accent;
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radii.md),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.all(t.spacing.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(t.radii.md),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              _PillIcon(
                icon: icon,
                color: iconColor,
                filled: tone != _OverlayTone.neutral,
              ),
              SizedBox(width: t.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: context.appText.bodyStrong.copyWith(
                        color: tone == _OverlayTone.danger
                            ? t.colors.dangerFg
                            : t.colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: t.spacing.xs),
                    Text(
                      subtitle,
                      style: t.text.bodySmall?.copyWith(
                        color: t.colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: t.spacing.sm),
              Icon(Icons.chevron_right_rounded, color: t.colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      radius: t.radii.md,
      padding: EdgeInsets.all(t.spacing.md),
      color: t.colors.surface,
      borderColor: t.colors.border,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PillIcon(icon: icon, color: t.colors.accent, filled: true),
          SizedBox(height: t.spacing.md),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.appText.titleMedium.copyWith(
              color: t.colors.textPrimary,
            ),
          ),
          SizedBox(height: t.spacing.xs),
          Expanded(
            child: Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: t.text.bodyMedium?.copyWith(
                color: t.colors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: t.spacing.sm),
          const _FactBadge(
            icon: Icons.auto_awesome_rounded,
            label: 'Modo',
            value: 'Template',
            tone: _BadgeTone.accent,
          ),
        ],
      ),
    );
  }
}

class _PopupMenuRow extends StatelessWidget {
  const _PopupMenuRow({
    required this.icon,
    required this.label,
    this.tone = _OverlayTone.neutral,
  });

  final IconData icon;
  final String label;
  final _OverlayTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color =
        tone == _OverlayTone.danger ? t.colors.dangerFg : t.colors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        SizedBox(width: t.spacing.sm),
        Text(
          label,
          style: t.text.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onNew, required this.onTemplates});

  final VoidCallback onNew;
  final VoidCallback onTemplates;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.spacing.xl),
          child: AppCard(
            radius: t.radii.xl,
            padding: EdgeInsets.all(t.spacing.xl),
            color: t.colors.surface,
            borderColor: t.colors.border,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState(
                  title: AppStrings.emptySheetsTitle,
                  message: AppStrings.emptySheetsBody,
                  icon: Icons.table_chart_outlined,
                ),
                SizedBox(height: t.spacing.md),
                Wrap(
                  spacing: t.spacing.sm,
                  runSpacing: t.spacing.sm,
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
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.spacing.xl),
          child: AppCard(
            radius: t.radii.xl,
            padding: EdgeInsets.all(t.spacing.xl),
            color: t.colors.surface,
            borderColor: t.colors.border,
            child: EmptyState(
              title: AppStrings.noResultsTitle,
              message: AppStrings.noResultsBody(query),
              icon: Icons.search_off_outlined,
              actionLabel: AppStrings.clearSearch,
              onAction: onClear,
            ),
          ),
        ),
      ),
    );
  }
}
