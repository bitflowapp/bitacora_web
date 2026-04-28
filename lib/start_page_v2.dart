import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_system/motion.dart';
import 'design_system/typography.dart';
import 'ui/app_tokens.dart';
import 'screens/about_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/terms_screen.dart';
import 'services/demo_templates.dart';
import 'services/export_xlsx_service.dart';
import 'services/sheet_store.dart';
import 'widgets/command_palette.dart';

class StartPageV2 extends StatefulWidget {
  const StartPageV2({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<StartPageV2> createState() => _StartPageV2State();
}

class _QuickSearchIntent extends Intent {
  const _QuickSearchIntent();
}

class _CreateSheetIntent extends Intent {
  const _CreateSheetIntent();
}

class _OpenRecentIntent extends Intent {
  const _OpenRecentIntent();
}

class _StartPageV2State extends State<StartPageV2> {
  static const String _kPinnedKey = 'bitflow_pinned_sheet_ids_v1';
  static const String _kFavoriteKey = 'bitflow_favorite_sheet_ids_v1';
  static const String _kUsageKey = 'bitflow.start_v2_usage.v1';
  static const String _kLastTemplateKey = 'bitflow.start_v2.last_template.v1';

  static const int _kRecentLimit = 6;

  List<SheetMeta> _items = <SheetMeta>[];
  Set<String> _pinnedIds = <String>{};
  Set<String> _favoriteIds = <String>{};
  Map<String, int> _usage = <String, int>{};
  String _lastTemplate = '';

  bool _loading = true;
  bool _busy = false;
  String _busyLabel = '';

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await _loadPrefs();
    if (!mounted) return;
    await _reloadSheets();
  }

  Future<void> _loadPrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final pinned = sp.getStringList(_kPinnedKey) ?? const <String>[];
      final favorites = sp.getStringList(_kFavoriteKey) ?? const <String>[];
      final usageRaw = sp.getString(_kUsageKey) ?? '{}';
      final usageMap = _decodeUsage(usageRaw);
      final lastTemplate = sp.getString(_kLastTemplateKey) ?? '';

      if (!mounted) return;
      setState(() {
        _pinnedIds = pinned.where((e) => e.trim().isNotEmpty).toSet();
        _favoriteIds = favorites.where((e) => e.trim().isNotEmpty).toSet();
        _usage = usageMap;
        _lastTemplate = lastTemplate.trim();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pinnedIds = <String>{};
        _favoriteIds = <String>{};
        _usage = <String, int>{};
        _lastTemplate = '';
      });
    }
  }

  Map<String, int> _decodeUsage(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, int>{};
      final out = <String, int>{};
      for (final entry in decoded.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is int) {
          out[key] = value;
          continue;
        }
        if (value is num) {
          out[key] = value.toInt();
          continue;
        }
        if (value is String) {
          final parsed = int.tryParse(value);
          if (parsed != null) out[key] = parsed;
        }
      }
      return out;
    } catch (_) {
      return <String, int>{};
    }
  }

  Future<void> _persistPins() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_kPinnedKey, _pinnedIds.toList()..sort());
    } catch (_) {}
  }

  Future<void> _persistFavorites() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_kFavoriteKey, _favoriteIds.toList()..sort());
    } catch (_) {}
  }

  Future<void> _persistUsage() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kUsageKey, jsonEncode(_usage));
    } catch (_) {}
  }

  Future<void> _persistLastTemplate(String templateName) async {
    _lastTemplate = templateName.trim();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kLastTemplateKey, _lastTemplate);
    } catch (_) {}
  }

  Future<void> _reloadSheets() async {
    final list = List<SheetMeta>.from(SheetStore.list())
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final ids = list.map((e) => e.id).toSet();

    var dirtyPins = false;
    var dirtyFavorites = false;

    final nextPinned = Set<String>.from(_pinnedIds);
    final nextFavs = Set<String>.from(_favoriteIds);
    for (final id in _pinnedIds) {
      if (!ids.contains(id)) {
        nextPinned.remove(id);
        dirtyPins = true;
      }
    }
    for (final id in _favoriteIds) {
      if (!ids.contains(id)) {
        nextFavs.remove(id);
        dirtyFavorites = true;
      }
    }

    if (!mounted) return;
    setState(() {
      _items = list;
      _pinnedIds = nextPinned;
      _favoriteIds = nextFavs;
      _loading = false;
    });

    if (dirtyPins) unawaited(_persistPins());
    if (dirtyFavorites) unawaited(_persistFavorites());
  }

  void _setBusy(bool value, {String label = ''}) {
    if (!mounted) return;
    setState(() {
      _busy = value;
      _busyLabel = label;
    });
  }

  void _trackUsage(String key) {
    final next = Map<String, int>.from(_usage);
    next[key] = (next[key] ?? 0) + 1;
    setState(() => _usage = next);
    unawaited(_persistUsage());
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _flushSheetStoreBeforeOpen() async {
    try {
      await SheetStore.flushPendingWrites();
    } catch (_) {
      _showMessage(
        'Storage local limitado. Abrimos en modo temporal; exporta un ZIP si vas a recargar.',
      );
    }
  }

  String _formatRelative(DateTime date) {
    final local = date.toLocal();
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

  Future<void> _openSheetById(
    String id, {
    String? initialName,
    List<String>? initialHeaders,
  }) async {
    if (_busy) return;
    _setBusy(true, label: 'Abriendo hoja...');
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EditorScreen(
            isLight: widget.isLight,
            onToggleTheme: widget.onToggleTheme,
            sheetId: id,
            initialName: initialName,
            initialHeaders: initialHeaders,
          ),
        ),
      );
      _trackUsage('open_sheet');
    } finally {
      _setBusy(false);
      await _reloadSheets();
    }
  }

  Future<void> _createConfiguredSheet({
    required int cols,
    required int rows,
    required bool autoHeaders,
  }) async {
    if (_busy) return;
    _trackUsage('create_configured');
    final headers =
        autoHeaders ? List.generate(cols, (i) => 'Col ${i + 1}') : <String>[];
    final id = SheetStore.createNew();
    await _flushSheetStoreBeforeOpen();
    await _openSheetById(id, initialHeaders: headers.isEmpty ? null : headers);
  }

  Future<void> _showNewSheetDialog() async {
    if (_busy) return;
    var cols = 5;
    var rows = 10;
    var autoHeaders = true;

    final result = await showModalBottomSheet<_NewSheetConfig>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.tokens.colors.bg,
      builder: (ctx) {
        final t = ctx.tokens;
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  t.spacing.lg,
                  8,
                  t.spacing.lg,
                  t.spacing.lg,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nuevo relevamiento',
                      style: TextStyle(
                        color: t.colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configurá una planilla técnica para empezar rápido.',
                      style: TextStyle(
                        color: t.colors.textSecondary,
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Desde plantilla
                    _ActionSurface(
                      onTap: () => Navigator.of(ctx2).pop(
                        const _NewSheetConfig(fromTemplate: true),
                      ),
                      backgroundColor: t.colors.surfaceMuted,
                      borderColor: t.colors.border,
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: t.colors.accent.withValues(
                                alpha: t.colors.isLight ? 0.12 : 0.18,
                              ),
                              borderRadius: BorderRadius.circular(t.radii.xs),
                            ),
                            child: Icon(
                              Icons.dashboard_customize_rounded,
                              color: t.colors.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Desde plantilla',
                                  style: TextStyle(
                                    color: t.colors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Inspección, mantenimiento, edificios, petróleo…',
                                  style: TextStyle(
                                    color: t.colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: t.colors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // En blanco con config
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: t.colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(t.radii.sm),
                        border: Border.all(color: t.colors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: t.colors.accent.withValues(
                                    alpha: t.colors.isLight ? 0.12 : 0.18,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(t.radii.xs),
                                ),
                                child: Icon(
                                  Icons.table_chart_outlined,
                                  color: t.colors.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'En blanco',
                                style: TextStyle(
                                  color: t.colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _GridPreview(cols: cols, rows: rows),
                          const SizedBox(height: 16),
                          // Columnas
                          Text(
                            'Columnas',
                            style: TextStyle(
                              color: t.colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              for (final n in [3, 5, 8])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _SegmentChip(
                                    label: '$n',
                                    selected: cols == n,
                                    accent: t.colors.accent,
                                    onTap: () => setSheetState(() => cols = n),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Filas
                          Text(
                            'Filas iniciales',
                            style: TextStyle(
                              color: t.colors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              for (final n in [5, 10, 20])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _SegmentChip(
                                    label: '$n',
                                    selected: rows == n,
                                    accent: t.colors.accent,
                                    onTap: () => setSheetState(() => rows = n),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Encabezados
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Encabezados automáticos',
                                  style: TextStyle(
                                    color: t.colors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Switch(
                                value: autoHeaders,
                                onChanged: (v) =>
                                    setSheetState(() => autoHeaders = v),
                                activeThumbColor: t.colors.accent,
                                activeTrackColor:
                                    t.colors.accent.withValues(alpha: 0.38),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.of(ctx2).pop(
                                _NewSheetConfig(
                                  cols: cols,
                                  rows: rows,
                                  autoHeaders: autoHeaders,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: t.colors.accent,
                                foregroundColor: t.colors.surface,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(t.radii.pill),
                                ),
                              ),
                              child: Text(
                                'Crear relevamiento — $cols cols · $rows filas',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
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

    if (!mounted || result == null) return;
    if (result.fromTemplate) {
      await _showTemplateChooser();
    } else {
      await _createConfiguredSheet(
        cols: result.cols,
        rows: result.rows,
        autoHeaders: result.autoHeaders,
      );
    }
  }

  Future<void> _openMeta(SheetMeta meta) {
    return _openSheetById(meta.id, initialName: meta.title);
  }

  Future<void> _openMostRecent() async {
    final recent = _items.isNotEmpty ? _items.first : null;
    if (recent == null) {
      _showMessage(
        'Todavía no hay planillas. Creá una nueva o abrí la demo técnica.',
      );
      return;
    }
    _trackUsage('open_recent');
    await _openMeta(recent);
  }

  Future<void> _createBlankSheet() async {
    if (_busy) return;
    _trackUsage('create_blank');
    final id = SheetStore.createNew();
    await _flushSheetStoreBeforeOpen();
    await _openSheetById(id);
  }

  Future<void> _createTemplateSheet(TemplateKind kind) async {
    if (_busy) return;
    _trackUsage('create_template');
    final id = SheetStore.createFromTemplate(kind);
    await _flushSheetStoreBeforeOpen();
    await _persistLastTemplate(kind.name);
    await _openSheetById(id);
  }

  Future<void> _showTemplateChooser() async {
    final kind = await showModalBottomSheet<TemplateKind>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.tokens.colors.bg,
      builder: (ctx) {
        final t = ctx.tokens;
        final items =
            <(TemplateKind kind, String title, String subtitle, IconData icon)>[
          (
            TemplateKind.proteccionCatodica,
            'Proteccion catodica',
            'Progresiva, punto, ON/OFF, IR drop y evidencia.',
            Icons.bolt_rounded,
          ),
          (
            TemplateKind.resistividades,
            'Puesta a tierra',
            'PAT, resistencia, continuidad, estado y responsable.',
            Icons.straighten_rounded,
          ),
          (
            TemplateKind.plantilla,
            'Relevamiento con evidencias',
            'Cliente, sector, hallazgo, criticidad y acción.',
            Icons.auto_awesome_rounded,
          ),
          (
            TemplateKind.inventario,
            'Control operativo',
            'Equipo, control, valor, estado y acción.',
            Icons.inventory_2_rounded,
          ),
          (
            TemplateKind.checklist,
            'Inspección de campo',
            'Frente, actividad, estado, observaciones y evidencia.',
            Icons.task_alt_rounded,
          ),
        ];
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              t.spacing.lg,
              6,
              t.spacing.lg,
              t.spacing.lg,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 560 ? 2 : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: columns == 1 ? 2.7 : 1.2,
                  children: [
                    for (final item in items)
                      _ActionSurface(
                        onTap: () => Navigator.of(ctx).pop(item.$1),
                        backgroundColor: t.colors.surfaceMuted,
                        borderColor: t.colors.border,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(item.$4, color: t.colors.accent),
                            const SizedBox(height: 10),
                            Text(
                              item.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.subheadline.copyWith(
                                color: t.colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.$3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption1.copyWith(
                                color: t.colors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
    if (!mounted || kind == null) return;
    await _createTemplateSheet(kind);
  }

  Future<void> _openQuickSearch() async {
    if (_busy) return;
    final actions = <CommandAction>[
      CommandAction(
        id: 'create_blank',
        label: 'Nueva hoja',
        subtitle: 'Configurar y crear',
        shortcut: 'Ctrl/Cmd + N',
        icon: Icons.add_box_rounded,
        onSelected: () => unawaited(_showNewSheetDialog()),
      ),
      CommandAction(
        id: 'open_recent',
        label: 'Abrir reciente',
        subtitle: 'Continuar trabajo',
        shortcut: 'Ctrl/Cmd + O',
        icon: Icons.history_rounded,
        onSelected: () => unawaited(_openMostRecent()),
      ),
      CommandAction(
        id: 'template',
        label: 'Usar plantilla',
        subtitle: 'Plantillas técnicas',
        icon: Icons.auto_fix_high_rounded,
        onSelected: () => unawaited(_showTemplateChooser()),
      ),
      CommandAction(
        id: 'import',
        label: 'Importar datos',
        subtitle: 'JSON o ZIP de respaldo',
        icon: Icons.file_upload_rounded,
        onSelected: () => unawaited(_importData()),
      ),
    ];

    for (final meta in _items.take(40)) {
      final title =
          meta.title.trim().isEmpty ? 'Planilla sin título' : meta.title;
      actions.add(
        CommandAction(
          id: 'sheet_${meta.id}',
          label: title,
          subtitle: 'Actualizada ${_formatRelative(meta.updatedAt)}',
          icon: _pinnedIds.contains(meta.id)
              ? Icons.push_pin_rounded
              : Icons.description_rounded,
          onSelected: () => unawaited(_openMeta(meta)),
        ),
      );
    }

    _trackUsage('quick_search');
    await showCommandPalette(
      context,
      title: 'Buscar en Bit Flow',
      actions: actions,
    );
  }

  void _togglePinned(String id) {
    final next = Set<String>.from(_pinnedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    setState(() => _pinnedIds = next);
    _trackUsage('pin_toggle');
    unawaited(_persistPins());
  }

  void _toggleFavorite(String id) {
    final next = Set<String>.from(_favoriteIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    setState(() => _favoriteIds = next);
    _trackUsage('favorite_toggle');
    unawaited(_persistFavorites());
  }

  Future<void> _openAutomationSheet() async {
    final suggestions = _automationSuggestions;

    _trackUsage('automation_opened');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.tokens.colors.bg,
      builder: (ctx) {
        final t = ctx.tokens;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              t.spacing.lg,
              8,
              t.spacing.lg,
              t.spacing.lg,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final suggestion = suggestions[i];
                return _ActionSurface(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    unawaited(suggestion.onTap());
                  },
                  backgroundColor: t.colors.surfaceMuted,
                  borderColor: t.colors.border,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: t.colors.accent.withValues(
                            alpha: t.colors.isLight ? 0.12 : 0.18,
                          ),
                          borderRadius: BorderRadius.circular(t.radii.xs),
                        ),
                        child: Icon(suggestion.icon, color: t.colors.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion.title,
                              style: AppTypography.callout.copyWith(
                                color: t.colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              suggestion.subtitle,
                              style: AppTypography.caption1.copyWith(
                                color: t.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  List<_AutomationSuggestion> get _automationSuggestions {
    final recent = _items.isNotEmpty ? _items.first : null;

    final continueSubtitle = recent == null
        ? 'Planilla local en blanco.'
        : recent.title.trim().isEmpty
            ? 'Último archivo.'
            : recent.title;

    final templateSubtitle = _lastTemplate.isEmpty
        ? 'Demo técnica lista.'
        : 'Ultima: $_lastTemplate';

    return <_AutomationSuggestion>[
      _AutomationSuggestion(
        title: recent == null ? 'Nueva planilla' : 'Abrir reciente',
        subtitle: continueSubtitle,
        icon: recent == null
            ? Icons.playlist_add_rounded
            : Icons.play_circle_fill_rounded,
        onTap: () async {
          if (recent == null) {
            await _createBlankSheet();
          } else {
            await _openMeta(recent);
          }
        },
      ),
      _AutomationSuggestion(
        title: 'Demo técnica',
        subtitle: templateSubtitle,
        icon: Icons.bolt_rounded,
        onTap: () => _createTemplateSheet(TemplateKind.proteccionCatodica),
      ),
      _AutomationSuggestion(
        title: 'Importar datos',
        subtitle: 'JSON o ZIP de respaldo.',
        icon: Icons.system_update_alt_rounded,
        onTap: _importData,
      ),
      _AutomationSuggestion(
        title: 'Plantilla reciente',
        subtitle:
            _lastTemplate.isEmpty ? 'Elegir desde plantillas.' : _lastTemplate,
        icon: Icons.auto_awesome_motion_rounded,
        onTap: () async {
          if (_lastTemplate == TemplateKind.proteccionCatodica.name) {
            await _createTemplateSheet(TemplateKind.proteccionCatodica);
            return;
          }
          if (_lastTemplate == TemplateKind.resistividades.name) {
            await _createTemplateSheet(TemplateKind.resistividades);
            return;
          }
          if (_lastTemplate == TemplateKind.inventario.name) {
            await _createTemplateSheet(TemplateKind.inventario);
            return;
          }
          if (_lastTemplate == TemplateKind.checklist.name) {
            await _createTemplateSheet(TemplateKind.checklist);
            return;
          }
          if (_lastTemplate == TemplateKind.plantilla.name) {
            await _createTemplateSheet(TemplateKind.plantilla);
            return;
          }
          await _showTemplateChooser();
        },
      ),
    ];
  }

  Future<void> _openSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.tokens.colors.bg,
      builder: (ctx) {
        final accent = ctx.tokens.colors.accent;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    widget.isLight
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: accent,
                  ),
                  title: const Text('Alternar tema'),
                  subtitle: const Text('Modo claro/oscuro'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onToggleTheme();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.tune_rounded, color: accent),
                  title: const Text('Resetear sugerencias'),
                  subtitle: const Text('Limpia historial local'),
                  onTap: () {
                    setState(() => _usage = <String, int>{});
                    unawaited(_persistUsage());
                    Navigator.of(ctx).pop();
                    _showMessage('Sugerencias reiniciadas.');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openInfoSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.tokens.colors.bg,
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
                title: const Text('Términos'),
                onTap: () => Navigator.of(ctx).pop('terms'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'about':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
        );
        return;
      case 'privacy':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
        );
        return;
      case 'terms':
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(builder: (_) => const TermsScreen()),
        );
        return;
    }
  }

  Future<void> _openImportExportSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.tokens.colors.bg,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_rounded),
                title: const Text('Importar datos'),
                subtitle: const Text('Archivo JSON o ZIP de respaldo'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_importData());
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Exportar último archivo'),
                subtitle: const Text('Genera XLSX de la planilla mas reciente'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_exportMostRecent());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openMoreSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.tokens.colors.bg,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Ajustes'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_openSettingsSheet());
                },
              ),
              ListTile(
                leading: const Icon(Icons.flash_on_rounded),
                title: const Text('Atajos'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_openAutomationSheet());
                },
              ),
              ListTile(
                leading: const Icon(Icons.support_agent_rounded),
                title: const Text('Soporte'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => DiagnosticsScreen(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Informacion'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_openInfoSheet());
                },
              ),
              ListTile(
                leading: const Icon(Icons.monitor_heart_rounded),
                title: const Text('Diagnóstico'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => DiagnosticsScreen(),
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.import_export_rounded),
                title: const Text('Importar / Exportar'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_openImportExportSheet());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importData() async {
    if (_busy) return;
    final typeGroup = const XTypeGroup(
      label: 'Bit Flow Data',
      extensions: <String>['zip', 'json'],
    );
    final picked = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (picked == null) return;

    _setBusy(true, label: 'Importando datos...');
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _showMessage('Archivo vacio.');
        return;
      }

      final model = _decodeImportModel(bytes: bytes, fileName: picked.name);
      if (model == null) {
        _showMessage(
          'El archivo no parece ser un respaldo válido de Bit Flow.',
        );
        return;
      }

      final normalized = SheetStore.normalizeModel(model);
      normalized['savedAt'] = DateTime.now().toIso8601String();
      final id = SheetStore.createFromModel(normalized);
      await _flushSheetStoreBeforeOpen();
      _trackUsage('import_data');
      await _reloadSheets();
      if (!mounted) return;
      await _openSheetById(id);
      _showMessage('Datos importados. La planilla ya está lista para revisar.');
    } catch (e) {
      _showMessage('No se pudo importar. Revisá que sea un JSON o ZIP válido.');
    } finally {
      _setBusy(false);
    }
  }

  Map<String, dynamic>? _decodeImportModel({
    required Uint8List bytes,
    required String fileName,
  }) {
    final lower = fileName.toLowerCase().trim();
    if (lower.endsWith('.zip')) {
      return _decodeModelFromZip(bytes);
    }

    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return _modelFromDecoded(decoded);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _decodeModelFromZip(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);

    ArchiveFile? backupFile;
    ArchiveFile? sheetFile;
    for (final file in archive) {
      final name = file.name.trim();
      if (name == 'backup.json' || name.endsWith('/backup.json')) {
        backupFile = file;
      }
      if (name == 'sheet.json' || name.endsWith('/sheet.json')) {
        sheetFile = file;
      }
    }

    if (backupFile != null) {
      try {
        final decoded = jsonDecode(utf8.decode(_archiveBytes(backupFile)));
        return _modelFromDecoded(decoded);
      } catch (_) {}
    }
    if (sheetFile != null) {
      try {
        final decoded = jsonDecode(utf8.decode(_archiveBytes(sheetFile)));
        return _modelFromDecoded(decoded);
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic>? _modelFromDecoded(dynamic decoded) {
    if (decoded is! Map) return null;

    final directMap = decoded.cast<String, dynamic>();
    final directHeaders = directMap['headers'];
    final directRows = directMap['rows'];
    if (directHeaders is List && directRows is List) {
      return Map<String, dynamic>.from(directMap);
    }

    final sheet = directMap['sheet'];
    if (sheet is Map) {
      final sheetMap = sheet.cast<String, dynamic>();
      if (sheetMap['headers'] is List && sheetMap['rows'] is List) {
        return Map<String, dynamic>.from(sheetMap);
      }
    }
    return null;
  }

  Uint8List _archiveBytes(ArchiveFile file) {
    return Uint8List.fromList(file.content);
  }

  Future<void> _exportMostRecent() async {
    if (_busy) return;
    if (_items.isEmpty) {
      _showMessage('No hay planillas para exportar todavía.');
      return;
    }

    final target = _items.first;
    final raw = SheetStore.loadRaw(target.id);
    if (raw == null || raw.trim().isEmpty) {
      _showMessage('No se pudo leer esa planilla. Intenta abrirla primero.');
      return;
    }

    _setBusy(true, label: 'Exportando XLSX...');
    try {
      final parsed = _extractRowsAndHeaders(raw);
      await ExportXlsxService.download(
        fileName: _safeFileName(
          target.title.trim().isEmpty ? 'BitFlow' : target.title,
        ),
        headers: parsed.$1,
        rows: parsed.$2,
      );
      _trackUsage('export_data');
      _showMessage('XLSX listo para enviar: ${target.title}.xlsx');
    } catch (e) {
      _showMessage('No se pudo exportar. Intenta de nuevo o abre la planilla.');
    } finally {
      _setBusy(false);
    }
  }

  (List<String>, List<List<String>>) _extractRowsAndHeaders(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw Exception('JSON inválido');
    }
    final map = decoded.cast<String, dynamic>();
    final headers = (map['headers'] as List?)
            ?.map((e) => (e ?? '').toString())
            .toList(growable: false) ??
        const <String>[];

    final rowsRaw = (map['rows'] as List?) ?? const <dynamic>[];
    final rows = <List<String>>[];
    for (final row in rowsRaw) {
      if (row is List) {
        rows.add(row.map((e) => (e ?? '').toString()).toList(growable: false));
        continue;
      }
      if (row is Map) {
        final cells = (row['cells'] as List?)
                ?.map((e) => (e ?? '').toString())
                .toList(growable: false) ??
            const <String>[];
        rows.add(cells);
      }
    }
    return (headers, rows);
  }

  String _safeFileName(String value) {
    final cleaned = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.isEmpty ? 'Bit Flow' : cleaned;
  }

  String get _contextMessage {
    if (_items.isEmpty) return 'Listo para trabajar';
    if (_items.length == 1) return 'Continuá tu trabajo';
    final recent = _items.take(3).length;
    return '$recent recientes listos';
  }

  int get _totalRecordedRows =>
      _items.fold<int>(0, (sum, item) => sum + item.rows);

  Future<void> _openDemoTemplateSpec(
    DemoTemplateSpec spec, {
    String? titleOverride,
  }) async {
    if (_busy) return;
    _trackUsage('open_demo_template_${spec.slug}');
    _setBusy(true, label: 'Abriendo demo técnica...');
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EditorScreen(
            isLight: widget.isLight,
            onToggleTheme: widget.onToggleTheme,
            sheetId:
                'demo_${spec.slug}_${DateTime.now().millisecondsSinceEpoch}',
            initialName: titleOverride ?? spec.sheetName,
            initialHeaders: spec.headers,
            initialRows: spec.rows,
          ),
        ),
      );
    } finally {
      _setBusy(false);
      await _reloadSheets();
    }
  }

  Future<void> _openTechnicalDemo() {
    final spec = resolveDemoTemplateFromSlug('relevamiento-evidencias') ??
        kDemoTemplateSpecs.first;
    return _openDemoTemplateSpec(
      spec,
      titleOverride: 'Relevamiento técnico con evidencias',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_loading) {
      return ColoredBox(
        color: t.colors.bg,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final recent = _items.take(_kRecentLimit).toList(growable: false);
    final favorites = _items
        .where((e) => _favoriteIds.contains(e.id))
        .toList(growable: false);
    final pinned =
        _items.where((e) => _pinnedIds.contains(e.id)).toList(growable: false);

    final shortcuts = <ShortcutActivator, Intent>{
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          const _QuickSearchIntent(),
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
          const _QuickSearchIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, control: true):
          const _CreateSheetIntent(),
      const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
          const _CreateSheetIntent(),
      const SingleActivator(LogicalKeyboardKey.keyO, control: true):
          const _OpenRecentIntent(),
      const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
          const _OpenRecentIntent(),
    };

    return ColoredBox(
      color: t.colors.bg,
      child: Shortcuts(
        shortcuts: shortcuts,
        child: Actions(
          actions: <Type, Action<Intent>>{
            _QuickSearchIntent: CallbackAction<_QuickSearchIntent>(
              onInvoke: (_) {
                unawaited(_openQuickSearch());
                return null;
              },
            ),
            _CreateSheetIntent: CallbackAction<_CreateSheetIntent>(
              onInvoke: (_) {
                unawaited(_showNewSheetDialog());
                return null;
              },
            ),
            _OpenRecentIntent: CallbackAction<_OpenRecentIntent>(
              onInvoke: (_) {
                unawaited(_openMostRecent());
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 960;
                  final quickActions = <_QuickActionData>[
                    _QuickActionData(
                      title: 'Nuevo relevamiento',
                      subtitle: 'Configurá una planilla técnica',
                      icon: Icons.add_chart_rounded,
                      shortcut: 'Ctrl/Cmd + N',
                      onTap: _showNewSheetDialog,
                      featured: true,
                    ),
                    _QuickActionData(
                      title: 'Usar plantilla técnica',
                      subtitle: 'Inspección, PC, mantenimiento',
                      icon: Icons.dashboard_customize_rounded,
                      shortcut: 'Templates',
                      onTap: _showTemplateChooser,
                    ),
                    _QuickActionData(
                      title: 'Continuar trabajo reciente',
                      subtitle: recent.isEmpty
                          ? 'Sin planillas todavía'
                          : recent.first.title.trim().isEmpty
                              ? 'Última planilla'
                              : recent.first.title,
                      icon: Icons.history_rounded,
                      shortcut: 'Ctrl/Cmd + O',
                      onTap: _openMostRecent,
                    ),
                    _QuickActionData(
                      title: 'Demo técnica',
                      subtitle: 'Operadora Norte · evidencias',
                      icon: Icons.bolt_rounded,
                      shortcut: 'Showcase',
                      onTap: _openTechnicalDemo,
                    ),
                  ];

                  return Stack(
                    children: [
                      SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          t.spacing.lg,
                          t.spacing.sm,
                          t.spacing.lg,
                          26 + MediaQuery.of(context).padding.bottom,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1120),
                            child: AppMotionStaggered(
                              initialDelay: const Duration(milliseconds: 70),
                              step: const Duration(milliseconds: 52),
                              duration: AppMotion.slow,
                              children: [
                                _Header(
                                  statusLabel: _contextMessage,
                                  sheetCount: _items.length,
                                  rowsRecorded: _totalRecordedRows,
                                  syncLabel: 'Local',
                                  onMore: _openMoreSheet,
                                  onSearch: _openQuickSearch,
                                  onThemeToggle: widget.onToggleTheme,
                                  isLight: widget.isLight,
                                ),
                                const SizedBox(height: 18),
                                _SectionTitle(
                                  title: 'Empezar',
                                  subtitle:
                                      'Crear relevamiento, usar plantilla técnica o continuar trabajo',
                                ),
                                const SizedBox(height: 10),
                                GridView.count(
                                  crossAxisCount: isWide
                                      ? 4
                                      : constraints.maxWidth >= 560
                                          ? 2
                                          : 1,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: isWide
                                      ? 1.5
                                      : constraints.maxWidth >= 560
                                          ? 1.25
                                          : 2.75,
                                  children: [
                                    for (final action in quickActions)
                                      _QuickActionTile(
                                        data: action,
                                        disabled: _busy,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _SectionTitle(
                                  title: 'Últimos archivos',
                                  subtitle: 'Retoma trabajos guardados',
                                ),
                                const SizedBox(height: 10),
                                isWide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _SheetGroupCard(
                                              title: 'Recientes',
                                              emptyHint:
                                                  'Crea una planilla o usa una plantilla.',
                                              items: recent,
                                              onOpen: _openMeta,
                                              onFavoriteToggle: _toggleFavorite,
                                              onPinnedToggle: _togglePinned,
                                              favoriteIds: _favoriteIds,
                                              pinnedIds: _pinnedIds,
                                              formatter: _formatRelative,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _SheetGroupCard(
                                              title: 'Favoritos',
                                              emptyHint:
                                                  'Marca trabajos clave.',
                                              items: favorites,
                                              onOpen: _openMeta,
                                              onFavoriteToggle: _toggleFavorite,
                                              onPinnedToggle: _togglePinned,
                                              favoriteIds: _favoriteIds,
                                              pinnedIds: _pinnedIds,
                                              formatter: _formatRelative,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _SheetGroupCard(
                                              title: 'Fijados',
                                              emptyHint:
                                                  'Fija proyectos activos.',
                                              items: pinned,
                                              onOpen: _openMeta,
                                              onFavoriteToggle: _toggleFavorite,
                                              onPinnedToggle: _togglePinned,
                                              favoriteIds: _favoriteIds,
                                              pinnedIds: _pinnedIds,
                                              formatter: _formatRelative,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          _SheetGroupCard(
                                            title: 'Recientes',
                                            emptyHint:
                                                'Crea una planilla o usa una plantilla.',
                                            items: recent,
                                            onOpen: _openMeta,
                                            onFavoriteToggle: _toggleFavorite,
                                            onPinnedToggle: _togglePinned,
                                            favoriteIds: _favoriteIds,
                                            pinnedIds: _pinnedIds,
                                            formatter: _formatRelative,
                                          ),
                                          if (favorites.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            _SheetGroupCard(
                                              title: 'Favoritos',
                                              emptyHint:
                                                  'Marca trabajos clave.',
                                              items: favorites,
                                              onOpen: _openMeta,
                                              onFavoriteToggle: _toggleFavorite,
                                              onPinnedToggle: _togglePinned,
                                              favoriteIds: _favoriteIds,
                                              pinnedIds: _pinnedIds,
                                              formatter: _formatRelative,
                                            ),
                                          ],
                                          if (pinned.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            _SheetGroupCard(
                                              title: 'Fijados',
                                              emptyHint:
                                                  'Fija proyectos activos.',
                                              items: pinned,
                                              onOpen: _openMeta,
                                              onFavoriteToggle: _toggleFavorite,
                                              onPinnedToggle: _togglePinned,
                                              favoriteIds: _favoriteIds,
                                              pinnedIds: _pinnedIds,
                                              formatter: _formatRelative,
                                            ),
                                          ],
                                        ],
                                      ),
                                if (isWide) ...[
                                  const SizedBox(height: 18),
                                  const _ShortcutStrip(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_busy)
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.22),
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: t.spacing.lg,
                                  vertical: t.spacing.md,
                                ),
                                decoration: BoxDecoration(
                                  color: t.colors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(
                                    t.radii.sm,
                                  ),
                                  border: Border.all(color: t.colors.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: t.colors.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _busyLabel.trim().isEmpty
                                          ? 'Procesando...'
                                          : _busyLabel,
                                      style: AppTypography.callout.copyWith(
                                        color: t.colors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.statusLabel,
    required this.sheetCount,
    required this.rowsRecorded,
    required this.syncLabel,
    required this.onMore,
    required this.onSearch,
    required this.onThemeToggle,
    required this.isLight,
  });

  final String statusLabel;
  final int sheetCount;
  final int rowsRecorded;
  final String syncLabel;
  final VoidCallback onMore;
  final VoidCallback onSearch;
  final VoidCallback onThemeToggle;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accentSoft = t.colors.accent.withValues(
      alpha: t.colors.isLight ? 0.10 : 0.18,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: t.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(t.radii.xl),
        border: Border.all(color: t.colors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: t.colors.isLight ? 0.06 : 0.28,
            ),
            blurRadius: 32,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;

          final brand = Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.colors.accent,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: t.colors.accent.withValues(alpha: 0.32),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Bit Flow',
                style: AppTypography.title2.copyWith(
                  color: t.colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 10),
              _StatusPill(label: statusLabel),
            ],
          );

          final headline = Text(
            'Planillas técnicas con evidencias en campo.',
            style: AppTypography.title1.copyWith(
              color: t.colors.textPrimary,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
              height: 1.05,
            ),
          );

          final subtitle = Text(
            'Relevá, documentá y exportá inspecciones desde el celular.',
            style: AppTypography.subheadline.copyWith(
              color: t.colors.textSecondary,
              height: 1.35,
            ),
          );

          final metrics = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                icon: Icons.description_rounded,
                label: 'Hojas',
                value: '$sheetCount',
                accentSoft: accentSoft,
              ),
              _MetricChip(
                icon: Icons.layers_rounded,
                label: 'Registros',
                value: _formatCompactCount(rowsRecorded),
                accentSoft: accentSoft,
              ),
              _MetricChip(
                icon: Icons.cloud_done_rounded,
                label: 'Sinc.',
                value: syncLabel,
                accentSoft: accentSoft,
              ),
            ],
          );

          final chromeActions = Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: compact ? WrapAlignment.start : WrapAlignment.end,
            children: [
              _GhostIconButton(
                icon: Icons.search_rounded,
                tooltip: 'Buscar',
                onTap: onSearch,
              ),
              _GhostIconButton(
                icon: isLight
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                tooltip: isLight ? 'Modo noche' : 'Modo día',
                onTap: onThemeToggle,
              ),
              _GhostIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: 'Más',
                onTap: onMore,
              ),
            ],
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                brand,
                const SizedBox(height: 12),
                chromeActions,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: brand),
                    const SizedBox(width: 12),
                    chromeActions,
                  ],
                ),
              const SizedBox(height: 22),
              headline,
              const SizedBox(height: 10),
              subtitle,
              const SizedBox(height: 18),
              metrics,
            ],
          );
        },
      ),
    );
  }
}

String _formatCompactCount(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) {
    final k = (n / 1000);
    return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
  }
  return '${(n / 1000).round()}k';
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dot = t.colors.successFg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: t.colors.successBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dot.withValues(alpha: t.colors.isLight ? 0.20 : 0.32),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dot,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: AppTypography.caption1.copyWith(
              color: t.colors.textPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentSoft,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentSoft;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: t.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accentSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: t.colors.accent),
          ),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.caption2.copyWith(
                  color: t.colors.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                value,
                style: AppTypography.subheadline.copyWith(
                  color: t.colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  const _GhostIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: t.colors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: t.colors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 18, color: t.colors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.title3.copyWith(
            color: t.colors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTypography.caption1.copyWith(color: t.colors.textSecondary),
        ),
      ],
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.shortcut,
    required this.onTap,
    this.featured = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String shortcut;
  final Future<void> Function() onTap;
  final bool featured;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.data, required this.disabled});

  final _QuickActionData data;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final featuredFg = t.colors.textPrimary.computeLuminance() > 0.5
        ? t.colors.bg
        : Colors.white;
    final foreground = data.featured ? featuredFg : t.colors.textPrimary;
    final secondary = data.featured
        ? featuredFg.withValues(alpha: 0.74)
        : t.colors.textSecondary;
    final accentSoft = t.colors.accent.withValues(
      alpha: t.colors.isLight ? 0.12 : 0.18,
    );
    return _ActionSurface(
      backgroundColor:
          data.featured ? t.colors.textPrimary : t.colors.surfaceMuted,
      borderColor: data.featured ? Colors.transparent : t.colors.border,
      disabled: disabled,
      onTap: () => unawaited(data.onTap()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: data.featured
                      ? featuredFg.withValues(alpha: 0.14)
                      : accentSoft,
                  borderRadius: BorderRadius.circular(t.radii.xs),
                ),
                child: Icon(
                  data.icon,
                  color: data.featured ? featuredFg : t.colors.accent,
                ),
              ),
              const Spacer(),
              _ShortcutBadge(
                label: data.shortcut,
                inverted: data.featured,
                invertedColor: featuredFg,
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.title,
            style: AppTypography.callout.copyWith(
              color: foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            style: AppTypography.caption1.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }
}

class _SheetGroupCard extends StatelessWidget {
  const _SheetGroupCard({
    required this.title,
    required this.emptyHint,
    required this.items,
    required this.onOpen,
    required this.onFavoriteToggle,
    required this.onPinnedToggle,
    required this.favoriteIds,
    required this.pinnedIds,
    required this.formatter,
  });

  final String title;
  final String emptyHint;
  final List<SheetMeta> items;
  final Future<void> Function(SheetMeta) onOpen;
  final void Function(String id) onFavoriteToggle;
  final void Function(String id) onPinnedToggle;
  final Set<String> favoriteIds;
  final Set<String> pinnedIds;
  final String Function(DateTime) formatter;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.all(t.spacing.sm),
      decoration: BoxDecoration(
        color: t.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(t.radii.md),
        border: Border.all(color: t.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${items.length})',
            style: AppTypography.footnote.copyWith(
              color: t.colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              emptyHint,
              style: AppTypography.caption1.copyWith(
                color: t.colors.textSecondary,
              ),
            )
          else
            Column(
              children: [
                for (final item in items.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _SheetMiniRow(
                      key: ValueKey<String>(item.id),
                      meta: item,
                      isFavorite: favoriteIds.contains(item.id),
                      isPinned: pinnedIds.contains(item.id),
                      subtitle: formatter(item.updatedAt),
                      onOpen: () => unawaited(onOpen(item)),
                      onFavoriteToggle: () => onFavoriteToggle(item.id),
                      onPinnedToggle: () => onPinnedToggle(item.id),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SheetMiniRow extends StatelessWidget {
  const _SheetMiniRow({
    super.key,
    required this.meta,
    required this.isFavorite,
    required this.isPinned,
    required this.subtitle,
    required this.onOpen,
    required this.onFavoriteToggle,
    required this.onPinnedToggle,
  });

  final SheetMeta meta;
  final bool isFavorite;
  final bool isPinned;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onPinnedToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final title =
        meta.title.trim().isEmpty ? 'Planilla sin título' : meta.title;
    final rowBg = t.colors.accent.withValues(
      alpha: t.colors.isLight ? 0.055 : 0.08,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radii.xs),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(t.radii.xs),
            color: rowBg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.footnote.copyWith(
                        color: t.colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.caption2.copyWith(
                        color: t.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite ? 'Quitar favorito' : 'Agregar favorito',
                icon: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 18,
                ),
                color: isFavorite
                    ? const Color(0xFFCC9A2A)
                    : t.colors.textSecondary,
                onPressed: onFavoriteToggle,
              ),
              IconButton(
                tooltip: isPinned ? 'Desfijar' : 'Fijar',
                icon: Icon(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 18,
                ),
                color: isPinned ? t.colors.accent : t.colors.textSecondary,
                onPressed: onPinnedToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutStrip extends StatelessWidget {
  const _ShortcutStrip();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: EdgeInsets.all(t.spacing.sm),
      decoration: BoxDecoration(
        color: t.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(t.radii.sm),
        border: Border.all(color: t.colors.border),
      ),
      child: const Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _ShortcutItem(combo: 'Ctrl/Cmd + K', label: 'Buscar'),
          _ShortcutItem(combo: 'Ctrl/Cmd + N', label: 'Nueva planilla'),
          _ShortcutItem(combo: 'Ctrl/Cmd + O', label: 'Abrir reciente'),
        ],
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  const _ShortcutItem({required this.combo, required this.label});

  final String combo;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            combo,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFamily: 'SF Pro Text',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
              fontFamily: 'SF Pro Text',
            ),
          ),
        ],
      ),
    );
  }
}

class _AutomationSuggestion {
  const _AutomationSuggestion({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Future<void> Function() onTap;
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({
    required this.label,
    this.inverted = false,
    this.invertedColor,
  });

  final String label;
  final bool inverted;
  final Color? invertedColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final invertedFg = invertedColor ?? Colors.white;
    final accentSoft = t.colors.accent.withValues(
      alpha: t.colors.isLight ? 0.12 : 0.18,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: inverted ? invertedFg.withValues(alpha: 0.14) : accentSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              inverted ? invertedFg.withValues(alpha: 0.18) : t.colors.border,
        ),
      ),
      child: Text(
        label,
        style: AppTypography.caption2.copyWith(
          color: inverted
              ? invertedFg.withValues(alpha: 0.82)
              : t.colors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionSurface extends StatefulWidget {
  const _ActionSurface({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.disabled = false,
    this.onTap,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final bool disabled;
  final VoidCallback? onTap;

  @override
  State<_ActionSurface> createState() => _ActionSurfaceState();
}

class _ActionSurfaceState extends State<_ActionSurface> {
  bool _hovering = false;
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final enabled = !widget.disabled && widget.onTap != null;
    final bg = _hovering && enabled
        ? Color.lerp(widget.backgroundColor, Colors.white, 0.08) ??
            widget.backgroundColor
        : widget.backgroundColor;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pressing = false;
      }),
      child: Listener(
        onPointerDown: enabled ? (_) => setState(() => _pressing = true) : null,
        onPointerUp: enabled ? (_) => setState(() => _pressing = false) : null,
        onPointerCancel:
            enabled ? (_) => setState(() => _pressing = false) : null,
        child: AnimatedScale(
          scale: _pressing ? 0.982 : (_hovering && enabled ? 1.008 : 1),
          duration: AppMotion.resolve(context, AppMotion.fast),
          curve: AppMotion.press,
          child: AnimatedContainer(
            duration: AppMotion.resolve(context, AppMotion.fast),
            curve: AppMotion.swiftOut,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.borderColor),
              boxShadow: [
                if (_hovering && enabled)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: enabled ? widget.onTap : null,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewSheetConfig {
  const _NewSheetConfig({
    this.cols = 5,
    this.rows = 10,
    this.autoHeaders = true,
    this.fromTemplate = false,
  });
  final int cols;
  final int rows;
  final bool autoHeaders;
  final bool fromTemplate;
}

class _GridPreview extends StatelessWidget {
  const _GridPreview({required this.cols, required this.rows});

  final int cols;
  final int rows;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const previewRows = 4;
    final visibleRows = rows < previewRows ? rows : previewRows;
    final headerColor = t.colors.surfaceElevated;
    final altColor = t.colors.bg;
    final lineColor = t.colors.border;
    return Container(
      decoration: BoxDecoration(
        color: t.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lineColor),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (int c = 0; c < cols; c++) ...[
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: headerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                if (c < cols - 1) const SizedBox(width: 4),
              ],
            ],
          ),
          for (int r = 0; r < visibleRows; r++) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                for (int c = 0; c < cols; c++) ...[
                  Expanded(
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: r.isOdd ? altColor : t.colors.surfaceMuted,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  if (c < cols - 1) const SizedBox(width: 4),
                ],
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '$cols cols · $rows filas',
            style: AppTypography.caption2.copyWith(
              color: t.colors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent : accent.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : accent,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
