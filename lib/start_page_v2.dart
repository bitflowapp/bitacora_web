import 'dart:async';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_system/colors.dart';
import 'design_system/motion.dart';
import 'design_system/spacing.dart';
import 'design_system/typography.dart';
import 'screens/about_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/terms_screen.dart';
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
      SnackBar(content: Text(message)),
    );
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

  Future<void> _openSheetById(String id, {String? initialName}) async {
    if (_busy) return;
    _setBusy(true, label: 'Abriendo archivo...');
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => EditorScreen(
            isLight: widget.isLight,
            onToggleTheme: widget.onToggleTheme,
            sheetId: id,
            initialName: initialName,
          ),
        ),
      );
      _trackUsage('open_sheet');
    } finally {
      _setBusy(false);
      await _reloadSheets();
    }
  }

  Future<void> _openMeta(SheetMeta meta) {
    return _openSheetById(meta.id, initialName: meta.title);
  }

  Future<void> _openMostRecent() async {
    final recent = _items.isNotEmpty ? _items.first : null;
    if (recent == null) {
      _showMessage('No hay archivos recientes para abrir.');
      return;
    }
    _trackUsage('open_recent');
    await _openMeta(recent);
  }

  Future<void> _createBlankSheet() async {
    if (_busy) return;
    _trackUsage('create_blank');
    final id = SheetStore.createNew();
    await _openSheetById(id);
  }

  Future<void> _createTemplateSheet(TemplateKind kind) async {
    if (_busy) return;
    _trackUsage('create_template');
    final id = SheetStore.createFromTemplate(kind);
    await _persistLastTemplate(kind.name);
    await _openSheetById(id);
  }

  Future<void> _showTemplateChooser() async {
    final palette = _StartPalette(isLight: widget.isLight);
    final kind = await showModalBottomSheet<TemplateKind>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.sheetBg,
      builder: (ctx) {
        final items =
            <(TemplateKind kind, String title, String subtitle, IconData icon)>[
          (
            TemplateKind.plantilla,
            'Plantilla base',
            'Actividad, detalle, estado, responsable.',
            Icons.auto_awesome_rounded,
          ),
          (
            TemplateKind.resistividades,
            'Nueva medicion',
            'Fecha, progresiva, 1m, 3m, 5m.',
            Icons.straighten_rounded,
          ),
          (
            TemplateKind.inventario,
            'Inventario',
            'Item, cantidad, unidad y ubicacion.',
            Icons.inventory_2_rounded,
          ),
          (
            TemplateKind.checklist,
            'Checklist',
            'Tarea, estado, fecha y comentario.',
            Icons.task_alt_rounded,
          ),
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
              children: [
                for (final item in items)
                  _ActionSurface(
                    onTap: () => Navigator.of(ctx).pop(item.$1),
                    backgroundColor: palette.card,
                    borderColor: palette.border,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(item.$4, color: palette.accent),
                        const SizedBox(height: 10),
                        Text(
                          item.$2,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'SF Pro Text',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.$3,
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                            fontFamily: 'SF Pro Text',
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

    if (!mounted || kind == null) return;
    await _createTemplateSheet(kind);
  }

  Future<void> _openQuickSearch() async {
    if (_busy) return;
    final actions = <CommandAction>[
      CommandAction(
        id: 'create_blank',
        label: 'Nueva planilla',
        subtitle: 'Crear una planilla vacia y abrir editor',
        shortcut: 'Ctrl/Cmd + N',
        icon: Icons.add_box_rounded,
        onSelected: () => unawaited(_createBlankSheet()),
      ),
      CommandAction(
        id: 'open_recent',
        label: 'Abrir reciente',
        subtitle: 'Continuar ultimo archivo',
        shortcut: 'Ctrl/Cmd + O',
        icon: Icons.history_rounded,
        onSelected: () => unawaited(_openMostRecent()),
      ),
      CommandAction(
        id: 'template',
        label: 'Automatizar tarea',
        subtitle: 'Crear desde sugerencia o template',
        icon: Icons.auto_fix_high_rounded,
        onSelected: () => unawaited(_openAutomationSheet()),
      ),
      CommandAction(
        id: 'import',
        label: 'Importar datos',
        subtitle: 'Restaurar archivo JSON/ZIP',
        icon: Icons.file_upload_rounded,
        onSelected: () => unawaited(_importData()),
      ),
    ];

    for (final meta in _items.take(40)) {
      final title =
          meta.title.trim().isEmpty ? 'Planilla sin titulo' : meta.title;
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
      title: 'Quick Search',
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
    final palette = _StartPalette(isLight: widget.isLight);
    final suggestions = _automationSuggestions;

    _trackUsage('automation_opened');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.sheetBg,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                  backgroundColor: palette.card,
                  borderColor: palette.border,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: palette.accentSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(suggestion.icon, color: palette.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion.title,
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                fontFamily: 'SF Pro Text',
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              suggestion.subtitle,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                                fontFamily: 'SF Pro Text',
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
    final openCount = _usage['open_recent'] ?? 0;
    final templateCount = _usage['create_template'] ?? 0;
    final importCount = _usage['import_data'] ?? 0;

    final continueSubtitle = recent == null
        ? 'Crea tu primera planilla para iniciar flujo.'
        : 'Ultimo archivo: ${recent.title.trim().isEmpty ? recent.id : recent.title}.';

    final templateSubtitle = _lastTemplate.isEmpty
        ? 'Ideal para relevamientos repetitivos.'
        : 'Ultima plantilla usada: $_lastTemplate.';

    return <_AutomationSuggestion>[
      _AutomationSuggestion(
        title: recent == null
            ? 'Crear primer proyecto'
            : 'Continuar ultimo proyecto',
        subtitle: '$continueSubtitle Uso: $openCount',
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
        title: 'Crear nueva medicion',
        subtitle: '$templateSubtitle Uso: $templateCount',
        icon: Icons.straighten_rounded,
        onTap: () => _createTemplateSheet(TemplateKind.resistividades),
      ),
      _AutomationSuggestion(
        title: 'Importar datos',
        subtitle: 'JSON/ZIP de respaldo. Uso: $importCount',
        icon: Icons.system_update_alt_rounded,
        onTap: _importData,
      ),
      _AutomationSuggestion(
        title: 'Abrir plantilla reciente',
        subtitle: _lastTemplate.isEmpty
            ? 'No hay plantilla reciente, abre galeria.'
            : 'Plantilla guardada: $_lastTemplate',
        icon: Icons.auto_awesome_motion_rounded,
        onTap: () async {
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
    final palette = _StartPalette(isLight: widget.isLight);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.sheetBg,
      builder: (ctx) {
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
                    color: palette.accent,
                  ),
                  title: const Text('Alternar tema'),
                  subtitle: const Text('Modo claro/oscuro'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    widget.onToggleTheme();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.tune_rounded, color: palette.accent),
                  title: const Text('Resetear sugerencias'),
                  subtitle: const Text('Limpia historial de automatizaciones'),
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
    final palette = _StartPalette(isLight: widget.isLight);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.sheetBg,
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
    final palette = _StartPalette(isLight: widget.isLight);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.sheetBg,
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
                title: const Text('Exportar ultimo archivo'),
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
    final palette = _StartPalette(isLight: widget.isLight);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.sheetBg,
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
                title: const Text('Diagnostico'),
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
        _showMessage('No se encontro un modelo valido en el archivo.');
        return;
      }

      final normalized = SheetStore.normalizeModel(model);
      normalized['savedAt'] = DateTime.now().toIso8601String();
      final id = SheetStore.createFromModel(normalized);
      _trackUsage('import_data');
      await _reloadSheets();
      if (!mounted) return;
      await _openSheetById(id);
      _showMessage('Datos importados correctamente.');
    } catch (e) {
      _showMessage('No se pudo importar: $e');
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
      _showMessage('No hay planillas para exportar.');
      return;
    }

    final target = _items.first;
    final raw = SheetStore.loadRaw(target.id);
    if (raw == null || raw.trim().isEmpty) {
      _showMessage('No se pudo leer la planilla seleccionada.');
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
      _showMessage('Exportacion completada: ${target.title}.xlsx');
    } catch (e) {
      _showMessage('No se pudo exportar: $e');
    } finally {
      _setBusy(false);
    }
  }

  (List<String>, List<List<String>>) _extractRowsAndHeaders(String rawJson) {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map) {
      throw Exception('JSON invalido');
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
        rows.add(
          row.map((e) => (e ?? '').toString()).toList(growable: false),
        );
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
    if (_items.length == 1) return 'Continua donde lo dejaste';
    final recent = _items.take(3).length;
    return '$recent archivos abiertos recientemente';
  }

  @override
  Widget build(BuildContext context) {
    final palette = _StartPalette(isLight: widget.isLight);

    if (_loading) {
      return ColoredBox(
        color: palette.background,
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
      color: palette.background,
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
                unawaited(_createBlankSheet());
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
                      title: 'Nueva planilla',
                      subtitle: 'Empieza en blanco',
                      icon: Icons.add_box_rounded,
                      shortcut: 'Ctrl/Cmd + N',
                      onTap: _createBlankSheet,
                    ),
                    _QuickActionData(
                      title: 'Abrir reciente',
                      subtitle: 'Retomar ultimo trabajo',
                      icon: Icons.history_rounded,
                      shortcut: 'Ctrl/Cmd + O',
                      onTap: _openMostRecent,
                    ),
                    _QuickActionData(
                      title: 'Buscar archivos',
                      subtitle: 'Quick Search global',
                      icon: Icons.search_rounded,
                      shortcut: 'Ctrl/Cmd + K',
                      onTap: _openQuickSearch,
                    ),
                    _QuickActionData(
                      title: 'Automatizar tarea',
                      subtitle: 'Sugerencias inteligentes',
                      icon: Icons.auto_fix_high_rounded,
                      shortcut: 'Smart',
                      onTap: _openAutomationSheet,
                    ),
                  ];

                  return Stack(
                    children: [
                      SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          10,
                          16,
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
                                  palette: palette,
                                  message: _contextMessage,
                                  subtitle:
                                      'Centro de control rapido para trabajo diario',
                                  onMore: _openMoreSheet,
                                  onThemeToggle: widget.onToggleTheme,
                                  isLight: widget.isLight,
                                ),
                                const SizedBox(height: 18),
                                _SectionTitle(
                                  palette: palette,
                                  title: 'Acciones rapidas',
                                  subtitle:
                                      'Solo 4 acciones clave para arrancar en segundos',
                                ),
                                const SizedBox(height: 10),
                                GridView.count(
                                  crossAxisCount: isWide ? 4 : 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: isWide ? 1.5 : 1.25,
                                  children: [
                                    for (final action in quickActions)
                                      _QuickActionTile(
                                        palette: palette,
                                        data: action,
                                        disabled: _busy,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _SectionTitle(
                                  palette: palette,
                                  title: 'Continuar trabajo',
                                  subtitle: 'Recientes, favoritos y fijados',
                                ),
                                const SizedBox(height: 10),
                                isWide
                                    ? Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: _SheetGroupCard(
                                              palette: palette,
                                              title: 'Recientes',
                                              emptyHint:
                                                  'Sin archivos recientes',
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
                                              palette: palette,
                                              title: 'Favoritos',
                                              emptyHint:
                                                  'Marca archivos con estrella',
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
                                              palette: palette,
                                              title: 'Fijados',
                                              emptyHint:
                                                  'Fija archivos para acceso inmediato',
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
                                            palette: palette,
                                            title: 'Recientes',
                                            emptyHint: 'Sin archivos recientes',
                                            items: recent,
                                            onOpen: _openMeta,
                                            onFavoriteToggle: _toggleFavorite,
                                            onPinnedToggle: _togglePinned,
                                            favoriteIds: _favoriteIds,
                                            pinnedIds: _pinnedIds,
                                            formatter: _formatRelative,
                                          ),
                                          const SizedBox(height: 10),
                                          _SheetGroupCard(
                                            palette: palette,
                                            title: 'Favoritos',
                                            emptyHint:
                                                'Marca archivos con estrella',
                                            items: favorites,
                                            onOpen: _openMeta,
                                            onFavoriteToggle: _toggleFavorite,
                                            onPinnedToggle: _togglePinned,
                                            favoriteIds: _favoriteIds,
                                            pinnedIds: _pinnedIds,
                                            formatter: _formatRelative,
                                          ),
                                          const SizedBox(height: 10),
                                          _SheetGroupCard(
                                            palette: palette,
                                            title: 'Fijados',
                                            emptyHint:
                                                'Fija archivos para acceso inmediato',
                                            items: pinned,
                                            onOpen: _openMeta,
                                            onFavoriteToggle: _toggleFavorite,
                                            onPinnedToggle: _togglePinned,
                                            favoriteIds: _favoriteIds,
                                            pinnedIds: _pinnedIds,
                                            formatter: _formatRelative,
                                          ),
                                        ],
                                      ),
                                const SizedBox(height: 18),
                                _SectionTitle(
                                  palette: palette,
                                  title: 'Automatizaciones',
                                  subtitle:
                                      'Sugerencias dinamicas segun uso real',
                                ),
                                const SizedBox(height: 10),
                                GridView.count(
                                  crossAxisCount: isWide ? 2 : 1,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: isWide ? 3.3 : 2.9,
                                  children: [
                                    for (final suggestion
                                        in _automationSuggestions)
                                      _AutomationTile(
                                        palette: palette,
                                        suggestion: suggestion,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _ShortcutStrip(palette: palette),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.card,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: palette.border),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: palette.accent,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _busyLabel.trim().isEmpty
                                          ? 'Procesando...'
                                          : _busyLabel,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'SF Pro Text',
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

class _StartPalette {
  const _StartPalette({required this.isLight});

  final bool isLight;

  Color get background => isLight ? AppColors.lightBg : AppColors.darkBg;
  Color get card =>
      isLight ? AppColors.lightSecondaryBg : AppColors.darkSecondaryBg;
  Color get sheetBg => isLight ? AppColors.lightBg : AppColors.darkSecondaryBg;
  Color get border => isLight ? AppColors.lightDivider : AppColors.darkDivider;
  Color get textPrimary => isLight ? AppColors.lightLabel : AppColors.darkLabel;
  Color get textSecondary =>
      isLight ? AppColors.lightSecondaryLabel : AppColors.darkSecondaryLabel;
  Color get accent => isLight ? AppColors.accentBlue : AppColors.accentBlueDark;
  Color get accentSoft => accent.withValues(alpha: isLight ? 0.12 : 0.18);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.palette,
    required this.message,
    required this.subtitle,
    required this.onMore,
    required this.onThemeToggle,
    required this.isLight,
  });

  final _StartPalette palette;
  final String message;
  final String subtitle;
  final VoidCallback onMore;
  final VoidCallback onThemeToggle;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppSpacing.xl),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(AppSpacing.md),
              border: Border.all(color: palette.border),
            ),
            alignment: Alignment.center,
            child: Text(
              'BF',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bit Flow',
                  style: AppTypography.headline.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Text(
                    message,
                    key: ValueKey<String>(message),
                    style: AppTypography.subheadline.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.caption1.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onThemeToggle,
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.textPrimary,
                  side: BorderSide(color: palette.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  size: 18,
                ),
                label: const Text('Tema'),
              ),
              FilledButton.icon(
                onPressed: onMore,
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.more_horiz_rounded, size: 18),
                label: const Text('Mas'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.palette,
    required this.title,
    required this.subtitle,
  });

  final _StartPalette palette;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            fontFamily: 'SF Pro Text',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontFamily: 'SF Pro Text',
          ),
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
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String shortcut;
  final Future<void> Function() onTap;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.palette,
    required this.data,
    required this.disabled,
  });

  final _StartPalette palette;
  final _QuickActionData data;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return _ActionSurface(
      backgroundColor: palette.card,
      borderColor: palette.border,
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
                  color: palette.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: palette.accent),
              ),
              const Spacer(),
              _ShortcutBadge(
                palette: palette,
                label: data.shortcut,
              ),
            ],
          ),
          const Spacer(),
          Text(
            data.title,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              fontFamily: 'SF Pro Text',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 12,
              fontFamily: 'SF Pro Text',
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetGroupCard extends StatelessWidget {
  const _SheetGroupCard({
    required this.palette,
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

  final _StartPalette palette;
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$title (${items.length})',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              fontFamily: 'SF Pro Text',
            ),
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text(
              emptyHint,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 12,
                fontFamily: 'SF Pro Text',
              ),
            )
          else
            Column(
              children: [
                for (final item in items.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _SheetMiniRow(
                      palette: palette,
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
    required this.palette,
    required this.meta,
    required this.isFavorite,
    required this.isPinned,
    required this.subtitle,
    required this.onOpen,
    required this.onFavoriteToggle,
    required this.onPinnedToggle,
  });

  final _StartPalette palette;
  final SheetMeta meta;
  final bool isFavorite;
  final bool isPinned;
  final String subtitle;
  final VoidCallback onOpen;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onPinnedToggle;

  @override
  Widget build(BuildContext context) {
    final title =
        meta.title.trim().isEmpty ? 'Planilla sin titulo' : meta.title;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: palette.accentSoft.withValues(alpha: 0.45),
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
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro Text',
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                        fontFamily: 'SF Pro Text',
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
                    : palette.textSecondary,
                onPressed: onFavoriteToggle,
              ),
              IconButton(
                tooltip: isPinned ? 'Desfijar' : 'Fijar',
                icon: Icon(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  size: 18,
                ),
                color: isPinned ? palette.accent : palette.textSecondary,
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
  const _ShortcutStrip({required this.palette});

  final _StartPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: const [
          _ShortcutItem(combo: 'Ctrl/Cmd + K', label: 'Quick Search'),
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

class _AutomationTile extends StatelessWidget {
  const _AutomationTile({
    required this.palette,
    required this.suggestion,
  });

  final _StartPalette palette;
  final _AutomationSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    return _ActionSurface(
      onTap: () => unawaited(suggestion.onTap()),
      backgroundColor: palette.card,
      borderColor: palette.border,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: palette.accentSoft,
            ),
            child: Icon(suggestion.icon, color: palette.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  suggestion.title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'SF Pro Text',
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  suggestion.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                    fontFamily: 'SF Pro Text',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutBadge extends StatelessWidget {
  const _ShortcutBadge({
    required this.palette,
    required this.label,
  });

  final _StartPalette palette;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'SF Pro Text',
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
