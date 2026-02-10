// lib/screens/start_page.dart
// StartPage (BitFlow) — Home “100% Apple (Cupertino-first), robusto y vendible.
//
// ✅ UPDATE (menú estilo Reminders iOS):
// - Agrega “dashboard superior: tarjetas Hoy/Programados/Todos/Con indicador/Terminados.
// - Agrega “Lista sugerida + “Mis listas (Raíz + Carpetas + Papelera).
// - Barra superior en píldora (Buscar / Nuevo / Más) como Reminders.
// - Botón flotante iOS (+) abajo a la derecha (NO Material FAB).
//
// ✅ FIX ENGINE (apunta al puerto):
// - Default inteligente: usa el MISMO host donde abriste la web + :8001 (en desktop: localhost -> 8001; en iPhone/Android: IP LAN -> 8001).
// - Normaliza lo que pegás: elimina /healthz, /docs, #/..., ?... y deja solo scheme://host:port.
// - Acepta pegar "192.168.x.x:8001" sin http://
//
// Mantiene:
// - SheetStore intacto
// - SharedPreferences (carpetas, notas, papelera, createdAt, prefs correo/engine)
// - ActionSheets / dialogs Cupertino
// - Lista/Grilla de planillas con acciones (export, renombrar, nota, mover, papelera)
//
// Dependencias:
//   - flutter_animate
//   - shared_preferences

import 'dart:async';
import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart'
    show Colors, Border, BorderRadius, BoxDecoration, BoxShadow, Offset;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../workers/json_worker.dart';
import '../services/engine_api.dart';
import '../services/engine_config.dart';
import '../services/sheet_store.dart';
import '../services/export_xlsx_service.dart';
import '../ui/ui.dart';
import 'about_screen.dart';
import 'editor_screen.dart';
import 'privacy_screen.dart';
import 'terms_screen.dart';

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

enum _HomeTab { sheets, trash }

enum _QuickFilter { none, today, flagged }

class _StartPageState extends State<StartPage> {
  // --------------------- Data ---------------------
  List<SheetMeta> _items = <SheetMeta>[];
  String _q = '';
  bool _searchAll = false;
  _ViewMode _view = _ViewMode.list;
  _SortMode _sort = _SortMode.updatedDesc;
  _HomeTab _tab = _HomeTab.sheets;

  // Dashboard UX
  bool _showSearch = false;
  _QuickFilter _quick = _QuickFilter.none;

  // Carpeta seleccionada (solo aplica en _HomeTab.sheets)
  String _selectedFolderId = ''; // '' = Raíz

  // --------------------- Preferences (correo destino + engine url) ---------------------
  static const String _kPrefDefaultEmail = 'bitflow.default_email';
  static const String _kPrefAutoSend = 'bitflow.auto_send';

  // ✅ Engine URL (FastAPI / Python)
  static const String _kPrefEngineBaseUrlLegacy = 'bitflow.engine_base_url';
  static const int _kDefaultEnginePort = 8001;

  String _defaultEmail = '';
  bool _autoSend = true;

  // Engine config (auto/manual + last resolved)
  String _engineMode = EngineConfig.modeAuto;
  String _manualEngineBaseUrl = '';
  String? _lastResolvedEngineBaseUrl;

  // --------------------- Organization state (folders, notes, trash, createdAt) ---------------------
  static const int _trashTtlDays = 14;

  static const String _kPrefFolders = 'bitflow.folders.v1';
  static const String _kPrefSheetFolder = 'bitflow.sheet_folder.v1';
  static const String _kPrefSheetCreatedAt = 'bitflow.sheet_created_at.v1';
  static const String _kPrefSheetNotes = 'bitflow.sheet_notes.v1';
  static const String _kPrefTrash = 'bitflow.trash.v1';

  bool _orgLoaded = false;

  final List<_Folder> _folders = <_Folder>[];
  final Map<String, String> _sheetFolder =
      <String, String>{}; // sheetId -> folderId
  final Map<String, int> _sheetCreatedAtMs = <String, int>{}; // sheetId -> ms
  final Map<String, String> _sheetNotes = <String, String>{}; // sheetId -> note
  final Map<String, int> _trashDeletedAtMs =
      <String, int>{}; // sheetId -> deletedAtMs

  // --------------------- Busy state ---------------------
  bool _busy = false;
  String? _busySheetId;

  // --------------------- Controllers ---------------------
  late final TextEditingController _searchEC;

  static const String _kBuildSha =
      String.fromEnvironment('GIT_SHA', defaultValue: 'dev');
  static const String _kBuildTime =
      String.fromEnvironment('BUILD_TIME', defaultValue: '');

  static String _shortSha(String sha) {
    final s = sha.trim();
    if (s.isEmpty || s == 'dev') return 'dev';
    return s.length <= 7 ? s : s.substring(0, 7);
  }

  String get _buildStamp {
    final sha = _shortSha(_kBuildSha);
    final ts = _kBuildTime.trim();
    if (ts.isEmpty) return 'Build: $sha';
    return 'Build: $sha  $ts';
  }

  // --------------------- Toast overlay ---------------------
  OverlayEntry? _toastEntry;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _searchEC = TextEditingController(text: _q);
    _reload();
    unawaited(_loadPrefs());
    unawaited(_loadOrg());
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _searchEC.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _items = SheetStore.list();
    });
    if (_orgLoaded) {
      unawaited(_syncCreatedAtForKnownSheets());
      unawaited(_purgeExpiredTrashIfNeeded());
    }
  }

  // --------------------- Engine defaults ---------------------

  String _manualEngineHint() {
    if (kIsWeb) return EngineConfig.defaultTunnelBaseUrl;

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return EngineConfig.defaultLanBaseUrl;
      default:
        return 'http://192.168.1.50:$_kDefaultEnginePort';
    }
  }

  // --------------------- Load/Save Prefs ---------------------

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final email = (p.getString(_kPrefDefaultEmail) ?? '').trim();
      final autoSend = p.getBool(_kPrefAutoSend) ?? true;

      final config = EngineConfig.instance;
      var mode = await config.mode;
      var manual = await config.manualBaseUrl;
      final lastResolved = await config.lastResolvedBaseUrl;

      final legacy = (p.getString(_kPrefEngineBaseUrlLegacy) ?? '').trim();
      if (manual == null && EngineConfig.isValidBaseUrl(legacy)) {
        manual = EngineConfig.normalize(legacy);
        await config.setManualBaseUrl(manual);
        await config.setMode(EngineConfig.modeManual);
        mode = EngineConfig.modeManual;
      }

      if (!mounted) return;
      setState(() {
        _defaultEmail = email;
        _autoSend = autoSend;
        _engineMode = mode;
        _manualEngineBaseUrl = manual ?? '';
        _lastResolvedEngineBaseUrl = lastResolved;
      });
    } catch (_) {
      if (!mounted) return;
    }
  }

  Future<void> _savePrefs({
    required String email,
    required bool autoSend,
    required String engineMode,
    required String manualBaseUrl,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPrefDefaultEmail, email.trim());
    await p.setBool(_kPrefAutoSend, autoSend);

    final config = EngineConfig.instance;
    await config.setMode(engineMode);
    if (manualBaseUrl.trim().isNotEmpty) {
      await config.setManualBaseUrl(manualBaseUrl);
    }
    final lastResolved = await config.lastResolvedBaseUrl;

    if (!mounted) return;
    setState(() {
      _defaultEmail = email.trim();
      _autoSend = autoSend;
      _engineMode = engineMode;
      _manualEngineBaseUrl = manualBaseUrl.trim();
      _lastResolvedEngineBaseUrl = lastResolved;
    });
  }

  bool _looksLikeHttpUrl(String s) {
    var v = s.trim();
    if (v.isEmpty) return true; // permitir “sin configurar

    return EngineConfig.isValidBaseUrl(v);
  }

  String? _engineBaseForEditor() {
    if (_engineMode != EngineConfig.modeManual) return null;
    final raw = _manualEngineBaseUrl.trim();
    if (!EngineConfig.isValidBaseUrl(raw)) return null;
    final normalized = EngineConfig.normalize(raw);
    return normalized.isEmpty ? null : normalized;
  }

  // --------------------- Load/Save Org (folders/trash/notes) ---------------------

  Future<void> _loadOrg() async {
    try {
      final p = await SharedPreferences.getInstance();

      final foldersRaw = p.getString(_kPrefFolders) ?? '[]';
      final folderMapRaw = p.getString(_kPrefSheetFolder) ?? '{}';
      final createdRaw = p.getString(_kPrefSheetCreatedAt) ?? '{}';
      final notesRaw = p.getString(_kPrefSheetNotes) ?? '{}';
      final trashRaw = p.getString(_kPrefTrash) ?? '{}';

      final foldersJson = _safeJsonDecodeList(foldersRaw);
      final folderMapJson = _safeJsonDecodeMap(folderMapRaw);
      final createdJson = _safeJsonDecodeMap(createdRaw);
      final notesJson = _safeJsonDecodeMap(notesRaw);
      final trashJson = _safeJsonDecodeMap(trashRaw);

      _folders
        ..clear()
        ..addAll(
          foldersJson
              .map((e) => _Folder.fromJson(e))
              .where((f) => f.id.isNotEmpty),
        );

      _sheetFolder
        ..clear()
        ..addAll(_mapStringString(folderMapJson));

      _sheetCreatedAtMs
        ..clear()
        ..addAll(_mapStringInt(createdJson));

      _sheetNotes
        ..clear()
        ..addAll(_mapStringString(notesJson));

      _trashDeletedAtMs
        ..clear()
        ..addAll(_mapStringInt(trashJson));

      if (!mounted) return;
      setState(() {
        _orgLoaded = true;
      });

      // Primera sincronización: createdAt para planillas existentes + purge TTL.
      await _syncCreatedAtForKnownSheets();
      await _purgeExpiredTrashIfNeeded();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _orgLoaded = true;
      });
    }
  }

  Future<void> _saveOrg() async {
    final p = await SharedPreferences.getInstance();

    final foldersJson = jsonEncode(_folders.map((f) => f.toJson()).toList());
    final folderMapJson = jsonEncode(_sheetFolder);
    final createdJson = jsonEncode(_sheetCreatedAtMs);
    final notesJson = jsonEncode(_sheetNotes);
    final trashJson = jsonEncode(_trashDeletedAtMs);

    await p.setString(_kPrefFolders, foldersJson);
    await p.setString(_kPrefSheetFolder, folderMapJson);
    await p.setString(_kPrefSheetCreatedAt, createdJson);
    await p.setString(_kPrefSheetNotes, notesJson);
    await p.setString(_kPrefTrash, trashJson);
  }

  Future<void> _syncCreatedAtForKnownSheets() async {
    // Regla: si no existe createdAt para un sheetId, lo fijamos con updatedAt (fallback),
    // y para nuevas planillas lo fijamos en _newSheet().
    bool changed = false;

    for (final m in _items) {
      if (!_sheetCreatedAtMs.containsKey(m.id)) {
        _sheetCreatedAtMs[m.id] = m.updatedAt.millisecondsSinceEpoch;
        changed = true;
      }

      // Folder inexistente -> raíz
      final fId = _sheetFolder[m.id];
      if (fId != null && fId.isNotEmpty && !_folders.any((f) => f.id == fId)) {
        _sheetFolder.remove(m.id);
        changed = true;
      }
    }

    if (changed) {
      await _saveOrg();
      if (!mounted) return;
      setState(() {});
    }
  }

  Future<void> _purgeExpiredTrashIfNeeded() async {
    // FIX CRTICO: si falla SheetStore.delete, NO removemos metadata.
    // De lo contrario la planilla "revive" en la lista principal.
    if (_trashDeletedAtMs.isEmpty) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final ttlMs = const Duration(days: _trashTtlDays).inMilliseconds;

    final expiredIds = <String>[];
    _trashDeletedAtMs.forEach((sheetId, deletedAtMs) {
      if (now - deletedAtMs >= ttlMs) expiredIds.add(sheetId);
    });

    if (expiredIds.isEmpty) return;

    int purged = 0;

    for (final id in expiredIds) {
      try {
        SheetStore.delete(id);

        // Solo si el delete fue OK, limpiamos metadata.
        _trashDeletedAtMs.remove(id);
        _sheetNotes.remove(id);
        _sheetFolder.remove(id);
        _sheetCreatedAtMs.remove(id);

        purged++;
      } catch (_) {
        // Se mantiene en papelera para no “revivir datos inconsistentes.
      }
    }

    if (purged == 0) return;

    await _saveOrg();

    // Refrescar lista real del store después de purgar.
    _reload();

    if (!mounted) return;
    _toast('Papelera: $purged planilla(s) eliminada(s) por vencimiento.');
  }

  // --------------------- Actions ---------------------

  Future<void> _newSheet() async {
    if (_busy) return;

    AppHaptics.light();
    final id = SheetStore.createNew();

    // createdAt real (fecha de creación)
    _sheetCreatedAtMs[id] = DateTime.now().millisecondsSinceEpoch;

    // Si estás parado en una carpeta (tab sheets), la planilla nace ahí
    if (_tab == _HomeTab.sheets && _selectedFolderId.isNotEmpty) {
      _sheetFolder[id] = _selectedFolderId;
    }

    await _saveOrg();

    _reload();
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => EditorScreen(
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
          sheetId: id,
          engineBaseUrl: _engineBaseForEditor(),
        ),
      ),
    );

    if (!mounted) return;
    _reload();
  }

  Future<void> _open(SheetMeta m) async {
    if (_busy) return;

    // Si está en papelera: pedimos restauración (más coherente)
    if (_trashDeletedAtMs.containsKey(m.id)) {
      final ok = await _confirmCupertino(
        title: 'Está en papelera',
        message:
            'Para abrir y editar, primero hay que restaurar la planilla. ¿Restaurar ahora?',
        okText: 'Restaurar',
      );
      if (ok != true) return;
      await _restoreFromTrash(m.id, silent: true);
    }

    if (!mounted) return;

    await Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => EditorScreen(
          isLight: widget.isLight,
          onToggleTheme: widget.onToggleTheme,
          sheetId: m.id,
          engineBaseUrl: _engineBaseForEditor(),
        ),
      ),
    );

    if (!mounted) return;
    _reload();
  }

  Future<void> _rename(SheetMeta m) async {
    if (_busy) return;

    final name = await _promptTextCupertino(
      title: 'Renombrar planilla',
      initialValue: m.title,
      placeholder: 'Ej: Relevamiento Pozo 12',
      okText: 'Guardar',
    );

    if (!mounted) return;
    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return;

    try {
      SheetStore.rename(m.id, trimmed);
      _reload();
    } catch (e) {
      _toast('No se pudo renombrar: $e');
    }
  }

  Future<void> _moveToTrash(SheetMeta m) async {
    if (_busy) return;

    final ok = await _confirmCupertino(
      title: 'Mover a papelera',
      message:
          'Se podrá recuperar durante $_trashTtlDays días. ¿Querés continuar?',
      okText: 'Mover',
      danger: true,
    );

    if (ok != true) return;

    _trashDeletedAtMs[m.id] = DateTime.now().millisecondsSinceEpoch;
    await _saveOrg();

    if (!mounted) return;
    setState(() {});
    _toast('Movida a papelera.');
  }

  Future<void> _restoreFromTrash(String sheetId, {bool silent = false}) async {
    _trashDeletedAtMs.remove(sheetId);
    await _saveOrg();
    if (!mounted) return;
    setState(() {});
    if (!silent) _toast('Planilla restaurada.');
  }

  Future<void> _deleteForever(SheetMeta m) async {
    if (_busy) return;

    final ok = await _confirmCupertino(
      title: 'Eliminar definitivamente',
      message: 'Esto borra los datos de forma irreversible. ¿Eliminar ahora?',
      okText: 'Eliminar',
      danger: true,
    );

    if (ok != true) return;

    try {
      SheetStore.delete(m.id);
    } catch (e) {
      _toast('No se pudo eliminar: $e');
      return;
    }

    _trashDeletedAtMs.remove(m.id);
    _sheetNotes.remove(m.id);
    _sheetFolder.remove(m.id);
    _sheetCreatedAtMs.remove(m.id);
    await _saveOrg();

    _reload();
    _toast('Eliminada definitivamente.');
  }

  Future<void> _exportSheet(SheetMeta m) async {
    if (_busy) return;

    final raw = SheetStore.loadRaw(m.id);
    if (raw == null) {
      _toast('No se pudo leer la planilla.');
      return;
    }

    setState(() {
      _busy = true;
      _busySheetId = m.id;
    });

    try {
      final parsed = await JsonWorker.parseOnce(raw);
      final name = _sanitizeFileName(m.title.isEmpty ? 'bitflow' : m.title);

      await ExportXlsxService.download(
        fileName: name, // sin “.xlsx
        headers: parsed.headers,
        rows: parsed.rows,
      );

      if (!mounted) return;
      AppHaptics.success();
      _toast('Exportado como $name.xlsx');

      // Estado de producto (sin fragilidad): avisamos configuración.
      if (_autoSend && _defaultEmail.isNotEmpty) {
        _toast('Auto-envío activo: destino ${_defaultEmail.trim()}');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Error al exportar XLSX: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _busySheetId = null;
        });
      } else {
        _busy = false;
        _busySheetId = null;
      }
    }
  }

  // --------------------- Notes (“mensaje destacado) ---------------------

  Future<void> _editNote(SheetMeta m) async {
    final current = (_sheetNotes[m.id] ?? '').trim();

    final result = await _promptMultilineCupertino(
      title: 'Mensaje destacado',
      initialValue: current,
      placeholder: 'Ej: “Enviar a cliente hoy 18:00 / “WP: revisar medición 3',
      okText: 'Guardar',
      extraAction: _PromptExtraAction(
        label: 'Limpiar',
        isDestructive: true,
        value: '',
      ),
    );

    if (result == null) return;

    final trimmed = result.trim();
    if (trimmed.isEmpty) {
      _sheetNotes.remove(m.id);
    } else {
      _sheetNotes[m.id] = trimmed;
    }

    await _saveOrg();
    if (!mounted) return;
    setState(() {});
    _toast(trimmed.isEmpty ? 'Mensaje limpiado.' : 'Mensaje guardado.');
  }

  // --------------------- Folder actions ---------------------

  Future<void> _openFolderPicker() async {
    if (!_orgLoaded) return;

    if (_tab == _HomeTab.trash) {
      // En papelera no hay carpeta activa.
      return;
    }

    final folders = List<_Folder>.from(_folders)
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return CupertinoActionSheet(
          title: const Text('Carpetas'),
          message: Text('Carpeta actual: ${_folderName(_selectedFolderId)}'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                setState(() {
                  _tab = _HomeTab.sheets;
                  _selectedFolderId = '';
                  _quick = _QuickFilter.none;
                });
              },
              child: const Text('Raíz'),
            ),
            for (final f in folders)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  setState(() {
                    _tab = _HomeTab.sheets;
                    _selectedFolderId = f.id;
                    _quick = _QuickFilter.none;
                  });
                },
                child: Text(f.name),
              ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                final created = await _createFolderDialog(context);
                if (created == null) return;
                if (!mounted) return;
                setState(() {
                  _tab = _HomeTab.sheets;
                  _selectedFolderId = created.id;
                  _quick = _QuickFilter.none;
                });
              },
              child: const Text('Nueva carpeta…'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openFolderManagerPage();
              },
              child: const Text('Gestionar carpetas…'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            isDefaultAction: true,
            child: const Text('Cancelar'),
          ),
        );
      },
    );
  }

  Future<void> _openFolderManagerPage() async {
    if (!_orgLoaded) return;

    await Navigator.of(context).push<void>(
      CupertinoPageRoute(
        builder: (_) => _FolderManagerPage(
          isLight: widget.isLight,
          folders: _folders,
          getCount: _countSheetsInFolder,
          onCreate: () => _createFolderDialog(_),
          onRename: (f) => _renameFolderDialog(_, f),
          onDelete: (f) => _deleteFolderFlow(_, f),
        ),
      ),
    );

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _deleteFolderFlow(BuildContext ctx, _Folder folder) async {
    final ok = await _confirmCupertino(
      ctx: ctx,
      title: 'Eliminar carpeta',
      message: 'Las planillas vuelven a “Raíz. ¿Eliminar “${folder.name}?',
      okText: 'Eliminar',
      danger: true,
    );
    if (ok != true) return;

    _folders.removeWhere((f) => f.id == folder.id);

    // Reasignar sheets a raíz
    final toMove = <String>[];
    _sheetFolder.forEach((sheetId, fId) {
      if (fId == folder.id) toMove.add(sheetId);
    });
    for (final sid in toMove) {
      _sheetFolder.remove(sid);
    }

    if (_selectedFolderId == folder.id) {
      _selectedFolderId = '';
    }

    await _saveOrg();
    if (!mounted) return;
    setState(() {});
    _toast('Carpeta eliminada.');
  }

  Future<_Folder?> _createFolderDialog(BuildContext ctx) async {
    final suggested = _monthYearLabel(DateTime.now());
    final name = await _promptTextCupertino(
      ctx: ctx,
      title: 'Crear carpeta',
      initialValue: suggested,
      placeholder: 'Ej: Agosto 2026',
      okText: 'Crear',
      info: _PromptInfo(
        title: 'Carpetas por mes',
        message:
            'Ejemplos: “$suggested, “Septiembre 2026, “Obra X. Un solo nivel, simple y ordenado.',
      ),
    );

    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return null;

    final id = 'f_${DateTime.now().millisecondsSinceEpoch}';
    final folder = _Folder(
      id: id,
      name: trimmed,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    _folders.add(folder);
    await _saveOrg();

    if (!mounted) return null;
    setState(() {});
    _toast('Carpeta creada: ${folder.name}');
    return folder;
  }

  Future<_Folder?> _renameFolderDialog(BuildContext ctx, _Folder folder) async {
    final name = await _promptTextCupertino(
      ctx: ctx,
      title: 'Renombrar carpeta',
      initialValue: folder.name,
      placeholder: 'Nombre',
      okText: 'Guardar',
    );

    final trimmed = (name ?? '').trim();
    if (trimmed.isEmpty) return null;

    final idx = _folders.indexWhere((f) => f.id == folder.id);
    if (idx < 0) return null;

    _folders[idx] = folder.copyWith(name: trimmed);
    await _saveOrg();
    if (!mounted) return null;
    setState(() {});
    _toast('Carpeta renombrada.');
    return _folders[idx];
  }

  Future<void> _moveSheetToFolder(SheetMeta m) async {
    if (_busy) return;
    if (!_orgLoaded) return;

    if (_tab == _HomeTab.trash) return;

    final folders = List<_Folder>.from(_folders)
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
    final currentFolderId = _sheetFolder[m.id] ?? '';

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return CupertinoActionSheet(
          title: const Text('Mover a carpeta'),
          message: Text('Actual: ${_folderName(currentFolderId)}'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                _sheetFolder.remove(m.id);
                await _saveOrg();
                if (!mounted) return;
                setState(() {});
                _toast('Movida a Raíz.');
              },
              child: const Text('Raíz'),
            ),
            for (final f in folders)
              CupertinoActionSheetAction(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  _sheetFolder[m.id] = f.id;
                  await _saveOrg();
                  if (!mounted) return;
                  setState(() {});
                  _toast('Movida a carpeta.');
                },
                child: Text(f.name),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            isDefaultAction: true,
            child: const Text('Cancelar'),
          ),
        );
      },
    );
  }

  int _countSheetsInFolder(String folderId) {
    int count = 0;
    for (final m in _items) {
      if (_trashDeletedAtMs.containsKey(m.id)) continue;
      final f = _sheetFolder[m.id] ?? '';
      if (f == folderId) count++;
    }
    return count;
  }

  int _countFlaggedSheets() {
    int c = 0;
    for (final m in _items) {
      if (_trashDeletedAtMs.containsKey(m.id)) continue;
      final note = (_sheetNotes[m.id] ?? '').trim();
      if (note.isNotEmpty) c++;
    }
    return c;
  }

  int _countTrash() => _trashDeletedAtMs.length;

  // --------------------- Settings UI (Mail + Engine) ---------------------

  Future<void> _openMailSettings() async {
    var engineMode = _engineMode;
    var lastResolved = _lastResolvedEngineBaseUrl;

    final emailEC = TextEditingController(text: _defaultEmail);
    final engineEC = TextEditingController(text: _manualEngineBaseUrl);

    bool autoSend = _autoSend;
    bool testing = false;

    final result = await showCupertinoDialog<_MailSettingsResult?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final email = emailEC.text.trim();
            final emailOk = email.isEmpty || _looksLikeEmail(email);

            final engine = engineEC.text.trim();
            final isManual = engineMode == EngineConfig.modeManual;
            final engineOk = !isManual || _looksLikeHttpUrl(engine);
            final resolvedLabel = (lastResolved ??
                (isManual ? 'Manual (sin resolver)' : 'Auto (sin resolver)'));

            return CupertinoAlertDialog(
              title: const Text('Ajustes'),
              content: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    _CupertinoInfoBanner(
                      icon: CupertinoIcons.cloud,
                      title: 'Motor (FastAPI)',
                      message: kIsWeb
                          ? 'Modo AUTO usa el tunel HTTPS. Si cambia el tunel, pasa a MANUAL y pega la nueva URL.'
                          : 'Modo AUTO intenta LAN y cae al tunel. En movil fisico usa IP LAN o tunel en MANUAL.',
                      isLight: widget.isLight,
                    ),
                    const SizedBox(height: 10),
                    CupertinoSlidingSegmentedControl<String>(
                      groupValue: engineMode,
                      children: const <String, Widget>{
                        EngineConfig.modeAuto: Text('AUTO'),
                        EngineConfig.modeManual: Text('MANUAL'),
                      },
                      onValueChanged: (v) {
                        if (v == null) return;
                        setLocal(() => engineMode = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    CupertinoTextField(
                      controller: engineEC,
                      enabled: isManual,
                      keyboardType: TextInputType.url,
                      placeholder: _manualEngineHint(),
                      autocorrect: false,
                      onChanged: (_) => setLocal(() {}),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(CupertinoIcons.cloud, size: 18),
                      ),
                    ),
                    if (!engineOk)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'URL inválida (usa http/https + host)',
                          style: TextStyle(
                            color: widget.isLight
                                ? const Color(0xFFB00020)
                                : const Color(0xFFFF6B6B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Base resuelta: $resolvedLabel',
                        style: TextStyle(
                          color: widget.isLight
                              ? const Color(0x88000000)
                              : const Color(0x99FFFFFF),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        onPressed: testing
                            ? null
                            : () async {
                                setLocal(() => testing = true);
                                final result = await _probeEngineConnection(
                                  mode: engineMode,
                                  manualBaseUrl: engineEC.text,
                                );
                                if (!mounted) return;
                                setLocal(() {
                                  testing = false;
                                  lastResolved =
                                      result.resolvedBase ?? lastResolved;
                                });
                                _toast(result.message);
                              },
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        color: widget.isLight
                            ? const Color(0xFFF0F2F7)
                            : const Color(0xFF1B1F2B),
                        borderRadius: BorderRadius.circular(10),
                        child:
                            Text(testing ? 'Probando...' : 'Probar conexion'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CupertinoInfoBanner(
                      icon: CupertinoIcons.paperplane,
                      title: 'Correo destino',
                      message:
                          'Registrá un correo destino. Tu flujo de export (Editor/Backend/Service) puede usarlo para enviar planillas sin pasos extra.',
                      isLight: widget.isLight,
                    ),
                    const SizedBox(height: 10),
                    CupertinoTextField(
                      controller: emailEC,
                      keyboardType: TextInputType.emailAddress,
                      placeholder: 'cliente@empresa.com',
                      autocorrect: false,
                      onChanged: (_) => setLocal(() {}),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      prefix: const Padding(
                        padding: EdgeInsets.only(left: 10),
                        child: Icon(CupertinoIcons.mail, size: 18),
                      ),
                    ),
                    if (!emailOk)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Correo inválido',
                          style: TextStyle(
                            color: widget.isLight
                                ? const Color(0xFFB00020)
                                : const Color(0xFFFF6B6B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    _CupertinoToggleRow(
                      title: 'Auto-envío al exportar',
                      subtitle:
                          'Activa la automatización cuando tu producto lo ejecute.',
                      value: autoSend,
                      onChanged: (v) => setLocal(() => autoSend = v),
                    ),
                  ],
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancelar'),
                ),
                CupertinoDialogAction(
                  onPressed: () {
                    final email = emailEC.text.trim();
                    final engine = engineEC.text.trim();

                    if (email.isNotEmpty && !_looksLikeEmail(email)) return;
                    if (engine.isNotEmpty && !_looksLikeHttpUrl(engine)) return;

                    Navigator.of(dialogContext).pop(
                      _MailSettingsResult(
                        email: email,
                        autoSend: autoSend,
                        engineMode: engineMode,
                        manualBaseUrl: engine.isEmpty
                            ? ''
                            : EngineConfig.normalize(engine),
                      ),
                    );
                  },
                  isDefaultAction: true,
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    emailEC.dispose();
    engineEC.dispose();

    if (result == null) return;

    await _savePrefs(
      email: result.email,
      autoSend: result.autoSend,
      engineMode: result.engineMode,
      manualBaseUrl: result.manualBaseUrl,
    );

    if (!mounted) return;

    if (_engineMode == EngineConfig.modeManual &&
        _manualEngineBaseUrl.trim().isNotEmpty) {
      _toast('Ajustes guardados. Engine: ${_manualEngineBaseUrl.trim()}');
    } else {
      _toast(_defaultEmail.isEmpty
          ? 'Ajustes guardados.'
          : 'Ajustes guardados (correo ok).');
    }
  }

  Future<_EngineProbeResult> _probeEngineConnection({
    required String mode,
    required String manualBaseUrl,
  }) async {
    final api = EngineApi();
    try {
      if (mode == EngineConfig.modeManual) {
        final raw = manualBaseUrl.trim();
        if (raw.isEmpty) {
          return const _EngineProbeResult(
            ok: false,
            message: 'URL manual vacia.',
            resolvedBase: null,
          );
        }
        if (!EngineConfig.isValidBaseUrl(raw)) {
          return const _EngineProbeResult(
            ok: false,
            message: 'URL manual invalida.',
            resolvedBase: null,
          );
        }
        final normalized = EngineConfig.normalize(raw);
        await api.getJsonFromBase(normalized, '/openapi.json');
        await EngineConfig.instance.setLastResolved(normalized);
        return _EngineProbeResult(
          ok: true,
          message: 'Conexion OK.',
          resolvedBase: normalized,
        );
      }

      await api.getJson('/openapi.json', cacheBust: true);
      final resolved = await EngineConfig.instance.lastResolvedBaseUrl;
      return _EngineProbeResult(
        ok: true,
        message: 'Conexion OK.',
        resolvedBase: resolved,
      );
    } catch (e) {
      return _EngineProbeResult(
        ok: false,
        message: _engineErrorMessage(e),
        resolvedBase: null,
      );
    } finally {
      api.dispose();
    }
  }

  String _engineErrorMessage(Object error) {
    if (error is EngineApiException) {
      return 'Engine error HTTP ${error.statusCode}: ${error.bodySnippet}';
    }
    final text = error.toString();
    if (kIsWeb &&
        (text.contains('XMLHttpRequest') || text.contains('Failed to fetch'))) {
      return 'CORS bloqueado: habilitar allow_origins en FastAPI para el dominio del tunel.';
    }
    return 'No se pudo conectar al engine. $text';
  }

  Future<void> _openAppPage(Widget page) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      CupertinoPageRoute<void>(builder: (_) => page),
    );
  }

  Future<void> _openMoreSheet(_ApplePalette colors) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return CupertinoActionSheet(
          title: const Text('Opciones'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                setState(() => _showSearch = !_showSearch);
              },
              child: Text(_showSearch ? 'Ocultar búsqueda' : 'Buscar'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openFolderPicker();
              },
              child: const Text('Carpetas…'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openMailSettings();
              },
              child: const Text('Ajustes (Correo/Motor)…'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openAppPage(const AboutScreen());
              },
              child: const Text('Acerca de…'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openAppPage(const PrivacyScreen());
              },
              child: const Text('Privacidad'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openAppPage(const TermsScreen());
              },
              child: const Text('Terminos'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openSortSheet();
              },
              child: const Text('Ordenar…'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openViewSheet();
              },
              child: const Text('Vista…'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                setState(() {
                  _tab = _tab == _HomeTab.sheets
                      ? _HomeTab.trash
                      : _HomeTab.sheets;
                  _quick = _QuickFilter.none;
                });
              },
              child: Text(
                  _tab == _HomeTab.sheets ? 'Ir a Papelera' : 'Ir a Planillas'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            isDefaultAction: true,
            child: const Text('Cancelar'),
          ),
        );
      },
    );
  }

  Future<void> _openSortSheet() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return CupertinoActionSheet(
          title: const Text('Ordenar'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                setState(() => _sort = _SortMode.updatedDesc);
              },
              isDefaultAction: _sort == _SortMode.updatedDesc,
              child: const Text('Recientes'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                setState(() => _sort = _SortMode.titleAsc);
              },
              isDefaultAction: _sort == _SortMode.titleAsc,
              child: const Text('Título (A–Z)'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                setState(() => _sort = _SortMode.rowsDesc);
              },
              isDefaultAction: _sort == _SortMode.rowsDesc,
              child: const Text('Más filas'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        );
      },
    );
  }

  Future<void> _openViewSheet() async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return CupertinoActionSheet(
          title: const Text('Vista'),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                setState(() => _view = _ViewMode.list);
              },
              isDefaultAction: _view == _ViewMode.list,
              child: const Text('Lista'),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!mounted) return;
                setState(() => _view = _ViewMode.grid);
              },
              isDefaultAction: _view == _ViewMode.grid,
              child: const Text('Cuadrícula'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
        );
      },
    );
  }

  void _applySummaryTap(_SummaryKind k) {
    if (!mounted) return;
    setState(() {
      _q = '';
      _searchEC.text = '';
      _quick = _QuickFilter.none;

      switch (k) {
        case _SummaryKind.today:
          _tab = _HomeTab.sheets;
          _quick = _QuickFilter.today;
          break;
        case _SummaryKind.scheduled:
          _tab = _HomeTab.sheets;
          _quick = _QuickFilter.none;
          break;
        case _SummaryKind.all:
          _tab = _HomeTab.sheets;
          _quick = _QuickFilter.none;
          break;
        case _SummaryKind.flagged:
          _tab = _HomeTab.sheets;
          _quick = _QuickFilter.flagged;
          break;
        case _SummaryKind.completed:
          _tab = _HomeTab.trash;
          _quick = _QuickFilter.none;
          break;
      }
    });
  }

  void _applyListTap(_ListKind kind, {String folderId = ''}) {
    if (!mounted) return;
    setState(() {
      _quick = _QuickFilter.none;
      _q = '';
      _searchEC.text = '';
      if (kind == _ListKind.trash) {
        _tab = _HomeTab.trash;
      } else {
        _tab = _HomeTab.sheets;
        _selectedFolderId = folderId;
      }
    });
  }

  // --------------------- UI helpers ---------------------

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

  String _fmtDateFromMs(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _sanitizeFileName(String s) {
    final r = RegExp(r'[\\/:*?"<>|]+');
    final cleaned = s.trim().replaceAll(r, '_');
    return cleaned.isEmpty ? 'bitflow' : cleaned;
  }

  bool _looksLikeEmail(String s) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+\.[^\s@]+$'); // fallback extra
    final re2 = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
    return (re2.hasMatch(s.trim()) || re.hasMatch(s.trim()));
  }

  String _folderName(String folderId) {
    if (folderId.isEmpty) return 'Raíz';
    for (final f in _folders) {
      if (f.id == folderId) return f.name;
    }
    return 'Raíz';
  }

  String _monthYearLabel(DateTime d) {
    const months = <String>[
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    final m = months[(d.month - 1).clamp(0, 11)];
    return '$m ${d.year}';
  }

  int _daysLeftInTrash(String sheetId) {
    final deleted = _trashDeletedAtMs[sheetId];
    if (deleted == null) return _trashTtlDays;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ttlMs = const Duration(days: _trashTtlDays).inMilliseconds;
    final leftMs = ttlMs - (now - deleted);
    final leftDays = (leftMs / const Duration(days: 1).inMilliseconds).ceil();
    return leftDays.clamp(0, _trashTtlDays);
  }

  Future<bool?> _confirmCupertino({
    BuildContext? ctx,
    required String title,
    required String message,
    required String okText,
    bool danger = false,
  }) async {
    final used = ctx ?? context;

    return showCupertinoDialog<bool>(
      context: used,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(message),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            isDestructiveAction: danger,
            isDefaultAction: !danger,
            child: Text(okText),
          ),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;

    _toastTimer?.cancel();
    _toastEntry?.remove();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final isLight = widget.isLight;

    _toastEntry = OverlayEntry(
      builder: (_) {
        return Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: _AppleToast(
            message: msg,
            isLight: isLight,
          ),
        );
      },
    );

    overlay.insert(_toastEntry!);

    _toastTimer = Timer(const Duration(milliseconds: 2200), () {
      _toastEntry?.remove();
      _toastEntry = null;
    });
  }

  Future<String?> _promptTextCupertino({
    BuildContext? ctx,
    required String title,
    String initialValue = '',
    String placeholder = '',
    String okText = 'OK',
    _PromptInfo? info,
  }) async {
    final used = ctx ?? context;
    final ec = TextEditingController(text: initialValue);

    final result = await showCupertinoDialog<String?>(
      context: used,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              children: [
                if (info != null) ...[
                  _CupertinoInfoBanner(
                    icon: CupertinoIcons.info,
                    title: info.title,
                    message: info.message,
                    isLight: widget.isLight,
                  ),
                  const SizedBox(height: 10),
                ],
                CupertinoTextField(
                  controller: ec,
                  placeholder: placeholder,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancelar'),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(ec.text.trim()),
              isDefaultAction: true,
              child: Text(okText),
            ),
          ],
        );
      },
    );

    ec.dispose();
    return result;
  }

  Future<String?> _promptMultilineCupertino({
    required String title,
    String initialValue = '',
    String placeholder = '',
    String okText = 'Guardar',
    _PromptExtraAction? extraAction,
  }) async {
    final ec = TextEditingController(text: initialValue);

    final result = await showCupertinoDialog<String?>(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: CupertinoTextField(
              controller: ec,
              placeholder: placeholder,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              maxLines: 4,
              minLines: 3,
              autofocus: true,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancelar'),
            ),
            if (extraAction != null)
              CupertinoDialogAction(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(extraAction.value),
                isDestructiveAction: extraAction.isDestructive,
                child: Text(extraAction.label),
              ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(ec.text.trim()),
              isDefaultAction: true,
              child: Text(okText),
            ),
          ],
        );
      },
    );

    ec.dispose();
    return result;
  }

  // ---------- Derivados UI (filtrado) ----------

  List<SheetMeta> get _visibleSheets {
    // Base: items del store
    var list = List<SheetMeta>.from(_items);

    // Tab + trash
    if (_tab == _HomeTab.trash) {
      list = list.where((m) => _trashDeletedAtMs.containsKey(m.id)).toList();
    } else {
      list = list.where((m) => !_trashDeletedAtMs.containsKey(m.id)).toList();

      // Folder filter (a menos que busquemos en todas)
      if (!_searchAll) {
        final fId = _selectedFolderId;
        list = list.where((m) => (_sheetFolder[m.id] ?? '') == fId).toList();
      }
    }

    // Quick filter
    if (_tab == _HomeTab.sheets && _quick != _QuickFilter.none) {
      final now = DateTime.now();
      if (_quick == _QuickFilter.today) {
        list = list.where((m) {
          final d = m.updatedAt.toLocal();
          return d.year == now.year && d.month == now.month && d.day == now.day;
        }).toList();
      } else if (_quick == _QuickFilter.flagged) {
        list = list
            .where((m) => (_sheetNotes[m.id] ?? '').trim().isNotEmpty)
            .toList();
      }
    }

    // Search (título o nota)
    final q = _q.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((m) {
        final title = (m.title.isEmpty ? 'Planilla' : m.title).toLowerCase();
        final note = (_sheetNotes[m.id] ?? '').toLowerCase();
        return title.contains(q) || note.contains(q);
      }).toList();
    }

    // Sort
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

  ({int total, int today, int totalRows}) get _statsAll {
    final now = DateTime.now();
    int total = 0;
    int today = 0;
    int totalRows = 0;

    for (final m in _items) {
      if (_trashDeletedAtMs.containsKey(m.id)) continue;
      total++;
      final d = m.updatedAt.toLocal();
      if (d.year == now.year && d.month == now.month && d.day == now.day)
        today++;
      totalRows += m.rows;
    }
    return (total: total, today: today, totalRows: totalRows);
  }

  ({int total, int totalRows}) get _statsView {
    final data = _visibleSheets;
    int totalRows = 0;
    for (final m in data) {
      totalRows += m.rows;
    }
    return (total: data.length, totalRows: totalRows);
  }

  // --------------------- Build ---------------------

  @override
  Widget build(BuildContext context) {
    final isLight = widget.isLight;
    final colors = _ApplePalette(isLight: isLight);

    final data = _visibleSheets;
    final sAll = _statsAll;

    final todayCount = sAll.today;
    final scheduledCount =
        0; // placeholder intencional (sin feature de agenda por ahora)
    final allCount = sAll.total;
    final flaggedCount = _countFlaggedSheets();
    final completedCount = _countTrash();

    final mq = MediaQuery.of(context);
    final bottomPad = mq.padding.bottom;
    final buildStamp = _buildStamp;

    return CupertinoPageScaffold(
      backgroundColor: colors.bg,
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                CupertinoSliverNavigationBar(
                  largeTitle: Text(
                    _tab == _HomeTab.trash ? 'Papelera' : 'BitFlow',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: colors.textPrimary,
                    ),
                  ),
                  backgroundColor: colors.navBarBg,
                  border: Border(bottom: BorderSide(color: colors.separator)),
                  leading: Semantics(
                    button: true,
                    label: AppStrings.semToggleTheme,
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: widget.onToggleTheme,
                      child: Icon(
                        isLight
                            ? CupertinoIcons.moon_stars
                            : CupertinoIcons.sun_max,
                        color: colors.accent,
                      ),
                    ),
                  ),
                  trailing: _TopPillActions(
                    colors: colors,
                    enabledAdd: !_busy && _tab != _HomeTab.trash,
                    onSearch: () => setState(() => _showSearch = !_showSearch),
                    onAdd: _newSheet,
                    onMore: () => _openMoreSheet(colors),
                  ),
                ),

                // Pull to refresh (iOS)
                CupertinoSliverRefreshControl(
                  onRefresh: () async => _reload(),
                ),

                // Dashboard (estilo Reminders)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: _RemindersSummaryGrid(
                      isLight: isLight,
                      today: todayCount,
                      scheduled: scheduledCount,
                      all: allCount,
                      flagged: flaggedCount,
                      completed: completedCount,
                      onTapToday: () => _applySummaryTap(_SummaryKind.today),
                      onTapScheduled: () =>
                          _applySummaryTap(_SummaryKind.scheduled),
                      onTapAll: () => _applySummaryTap(_SummaryKind.all),
                      onTapFlagged: () =>
                          _applySummaryTap(_SummaryKind.flagged),
                      onTapCompleted: () =>
                          _applySummaryTap(_SummaryKind.completed),
                    )
                        .animate()
                        .fadeIn(duration: 220.ms)
                        .move(begin: const Offset(0, 6)),
                  ),
                ),

                // Lista sugerida (como Reminders)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _SuggestedListCard(
                      colors: colors,
                      title: 'Lista sugerida: Carpeta del mes',
                      subtitle:
                          'Organiza automáticamente las planillas nuevas.',
                      onAdd: () async {
                        final created = await _createFolderDialog(context);
                        if (created == null) return;
                        if (!mounted) return;
                        setState(() {
                          _tab = _HomeTab.sheets;
                          _selectedFolderId = created.id;
                          _quick = _QuickFilter.none;
                        });
                      },
                    ),
                  ),
                ),

                // Mis listas (Raíz + carpetas + Papelera)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mis listas',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ListsCard(
                          colors: colors,
                          items: _buildHomeLists(colors),
                          onTap: (item) {
                            switch (item.kind) {
                              case _ListKind.root:
                                _applyListTap(_ListKind.root, folderId: '');
                                break;
                              case _ListKind.folder:
                                _applyListTap(_ListKind.folder,
                                    folderId: item.folderId);
                                break;
                              case _ListKind.trash:
                                _applyListTap(_ListKind.trash);
                                break;
                            }
                          },
                        ),
                      ],
                    ).animate().fadeIn(duration: 220.ms, delay: 40.ms),
                  ),
                ),

                // Search + scope (solo cuando se abre)
                if (_showSearch)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _AppleSectionCard(
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CupertinoSearchTextField(
                              controller: _searchEC,
                              onChanged: (v) => setState(() {
                                _q = v;
                              }),
                              placeholder:
                                  'Buscar por título o mensaje destacado…',
                            ),
                            if (_tab == _HomeTab.sheets) ...[
                              const SizedBox(height: 10),
                              _SegmentedScope(
                                isLight: isLight,
                                value: _searchAll,
                                onChanged: (v) =>
                                    setState(() => _searchAll = v),
                                colors: colors,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                // Caption de vista
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      _tab == _HomeTab.trash
                          ? 'Papelera: ${data.length} planilla(s)'
                          : _quick == _QuickFilter.today
                              ? 'Hoy: ${data.length} planilla(s)'
                              : _quick == _QuickFilter.flagged
                                  ? 'Con indicador: ${data.length} planilla(s)'
                                  : (_searchAll
                                      ? 'Mostrando ${data.length} (buscando en todas)'
                                      : 'Mostrando ${data.length} en “${_folderName(_selectedFolderId)}'),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                if (data.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
                      child: _AppleEmptyState(
                        colors: colors,
                        tab: _tab,
                        onNew: _newSheet,
                        onFolders: _openFolderPicker,
                        isBusy: _busy,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 180 + bottomPad),
                    sliver: _view == _ViewMode.list
                        ? SliverToBoxAdapter(
                            child: _AppleInsetGroupedList(
                              colors: colors,
                              children: [
                                for (int i = 0; i < data.length; i++)
                                  _AppleSheetRow(
                                    key: ValueKey('sheet_${data[i].id}'),
                                    colors: colors,
                                    meta: data[i],
                                    note:
                                        (_sheetNotes[data[i].id] ?? '').trim(),
                                    folderName: _folderName(
                                        _sheetFolder[data[i].id] ?? ''),
                                    fmt: _fmt,
                                    tab: _tab,
                                    busy: _busy && _busySheetId == data[i].id,
                                    daysLeftInTrash: _tab == _HomeTab.trash
                                        ? _daysLeftInTrash(data[i].id)
                                        : null,
                                    onOpen: () => _open(data[i]),
                                    onRename: () => _rename(data[i]),
                                    onExport: () => _exportSheet(data[i]),
                                    onEditNote: () => _editNote(data[i]),
                                    onMoveFolder: () =>
                                        _moveSheetToFolder(data[i]),
                                    onMoveToTrash: () => _moveToTrash(data[i]),
                                    onRestore: () =>
                                        _restoreFromTrash(data[i].id),
                                    onDeleteForever: () =>
                                        _deleteForever(data[i]),
                                  )
                                      .animate(delay: (30 + i * 20).ms)
                                      .fadeIn(duration: 180.ms)
                                      .move(begin: const Offset(0, 4)),
                              ],
                            ),
                          )
                        : SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final m = data[i];
                                return _AppleSheetGridCard(
                                  colors: colors,
                                  meta: m,
                                  note: (_sheetNotes[m.id] ?? '').trim(),
                                  folderName:
                                      _folderName(_sheetFolder[m.id] ?? ''),
                                  tab: _tab,
                                  busy: _busy && _busySheetId == m.id,
                                  daysLeftInTrash: _tab == _HomeTab.trash
                                      ? _daysLeftInTrash(m.id)
                                      : null,
                                  fmt: _fmt,
                                  onOpen: () => _open(m),
                                  onRename: () => _rename(m),
                                  onExport: () => _exportSheet(m),
                                  onEditNote: () => _editNote(m),
                                  onMoveFolder: () => _moveSheetToFolder(m),
                                  onMoveToTrash: () => _moveToTrash(m),
                                  onRestore: () => _restoreFromTrash(m.id),
                                  onDeleteForever: () => _deleteForever(m),
                                )
                                    .animate()
                                    .fadeIn(duration: 200.ms, delay: 30.ms);
                              },
                              childCount: data.length,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 2.35,
                            ),
                          ),
                  ),
              ],
            ),

            Positioned(
              left: 16,
              bottom: 14 + bottomPad,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.navBarBg.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.separator),
                  ),
                  child: Text(
                    buildStamp,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),

            // Botón flotante iOS (+) como Reminders (no Material FAB)
            if (_tab == _HomeTab.sheets)
              Positioned(
                right: 18,
                bottom: 18 + bottomPad,
                child: _FloatingAddButton(
                  color: colors.accent,
                  onTap: _busy ? null : _newSheet,
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<_HomeListItem> _buildHomeLists(_ApplePalette colors) {
    final items = <_HomeListItem>[];

    // Raíz
    items.add(
      _HomeListItem(
        kind: _ListKind.root,
        title: 'Raíz',
        icon: CupertinoIcons.list_bullet,
        iconBg: const Color(0xFFFF9F0A),
        count: _countSheetsInFolder(''),
        folderId: '',
        trailingBadge: null,
      ),
    );

    // Carpetas
    final foldersSorted = List<_Folder>.from(_folders)
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    for (final f in foldersSorted) {
      items.add(
        _HomeListItem(
          kind: _ListKind.folder,
          title: f.name,
          icon: CupertinoIcons.folder,
          iconBg: const Color(0xFFBF5AF2),
          count: _countSheetsInFolder(f.id),
          folderId: f.id,
          trailingBadge: null,
        ),
      );
    }

    // Papelera
    final trashCount = _countTrash();
    items.add(
      _HomeListItem(
        kind: _ListKind.trash,
        title: 'Papelera',
        icon: CupertinoIcons.trash,
        iconBg: const Color(0xFF8E8E93),
        count: trashCount,
        folderId: '',
        trailingBadge: trashCount > 0 ? '⚠' : null,
      ),
    );

    return items;
  }

  // --------------------- JSON helpers ---------------------

  List<Map<String, dynamic>> _safeJsonDecodeList(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
      return <Map<String, dynamic>>[];
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Map<String, dynamic> _safeJsonDecodeMap(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map) return v.cast<String, dynamic>();
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, String> _mapStringString(Map<String, dynamic> m) {
    final out = <String, String>{};
    m.forEach((k, v) {
      if (k is! String) return;
      if (v is String) out[k] = v;
      if (v is num) out[k] = v.toString();
    });
    return out;
  }

  Map<String, int> _mapStringInt(Map<String, dynamic> m) {
    final out = <String, int>{};
    m.forEach((k, v) {
      if (k is! String) return;
      if (v is int) out[k] = v;
      if (v is num) out[k] = v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) out[k] = parsed;
      }
    });
    return out;
  }
}

// ------------------------- Reminders-like widgets -------------------------

enum _SummaryKind { today, scheduled, all, flagged, completed }

enum _ListKind { root, folder, trash }

class _TopPillActions extends StatelessWidget {
  const _TopPillActions({
    required this.colors,
    required this.enabledAdd,
    required this.onSearch,
    required this.onAdd,
    required this.onMore,
  });

  final _ApplePalette colors;
  final bool enabledAdd;
  final VoidCallback onSearch;
  final VoidCallback onAdd;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final bg =
        colors.isLight ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);
    final border =
        colors.separator.withValues(alpha: colors.isLight ? 0.35 : 0.22);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: bg.withValues(alpha: colors.isLight ? 0.85 : 0.72),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(colors.isLight ? 0.08 : 0.45),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PillIcon(
                icon: CupertinoIcons.search,
                color: colors.textPrimary,
                semanticsLabel: 'Buscar planillas',
                onTap: onSearch,
              ),
              _PillDivider(color: border),
              _PillIcon(
                icon: CupertinoIcons.list_bullet_below_rectangle,
                color: enabledAdd ? colors.textPrimary : colors.muted,
                semanticsLabel: AppStrings.semAddSheet,
                onTap: enabledAdd ? onAdd : null,
              ),
              _PillDivider(color: border),
              _PillIcon(
                icon: CupertinoIcons.ellipsis,
                color: colors.textPrimary,
                semanticsLabel: 'Abrir menu de acciones',
                onTap: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillDivider extends StatelessWidget {
  const _PillDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: color,
    );
  }
}

class _PillIcon extends StatelessWidget {
  const _PillIcon({
    required this.icon,
    required this.color,
    required this.semanticsLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        minSize: 0,
        pressedOpacity: 0.55,
        onPressed: onTap,
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _RemindersSummaryGrid extends StatelessWidget {
  const _RemindersSummaryGrid({
    required this.isLight,
    required this.today,
    required this.scheduled,
    required this.all,
    required this.flagged,
    required this.completed,
    required this.onTapToday,
    required this.onTapScheduled,
    required this.onTapAll,
    required this.onTapFlagged,
    required this.onTapCompleted,
  });

  final bool isLight;

  final int today;
  final int scheduled;
  final int all;
  final int flagged;
  final int completed;

  final VoidCallback onTapToday;
  final VoidCallback onTapScheduled;
  final VoidCallback onTapAll;
  final VoidCallback onTapFlagged;
  final VoidCallback onTapCompleted;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, cs) {
        final w = cs.maxWidth;
        final gap = w < 420 ? 12.0 : 14.0;
        final cardH = w < 420 ? 98.0 : 106.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _SummaryCard(
                    height: cardH,
                    title: 'Hoy',
                    count: today,
                    icon: CupertinoIcons.calendar,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4FC3FF), Color(0xFF2D7DFF)],
                    ),
                    onTap: onTapToday,
                  ),
                  SizedBox(height: gap),
                  _SummaryCard(
                    height: cardH,
                    title: 'Todos',
                    count: all,
                    icon: CupertinoIcons.tray_full,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isLight
                          ? const [Color(0xFF3A3A3C), Color(0xFF1C1C1E)]
                          : const [Color(0xFF2C2C2E), Color(0xFF1C1C1E)],
                    ),
                    onTap: onTapAll,
                  ),
                  SizedBox(height: gap),
                  _SummaryCard(
                    height: cardH,
                    title: 'Terminados',
                    count: completed,
                    icon: CupertinoIcons.check_mark,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isLight
                          ? const [Color(0xFFB5B5BA), Color(0xFF8E8E93)]
                          : const [Color(0xFF8E8E93), Color(0xFF6B6B72)],
                    ),
                    onTap: onTapCompleted,
                  ),
                ],
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                children: [
                  _SummaryCard(
                    height: cardH,
                    title: 'Programados',
                    count: scheduled,
                    icon: CupertinoIcons.calendar_badge_plus,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF6B6B), Color(0xFFFF3B30)],
                    ),
                    onTap: onTapScheduled,
                  ),
                  SizedBox(height: gap),
                  _SummaryCard(
                    height: cardH,
                    title: 'Con indicador',
                    count: flagged,
                    icon: CupertinoIcons.flag,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFC566), Color(0xFFFF9F0A)],
                    ),
                    onTap: onTapFlagged,
                  ),
                  SizedBox(height: gap),
                  SizedBox(height: cardH),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.height,
    required this.title,
    required this.count,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final double height;
  final String title;
  final int count;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      pressedOpacity: 0.7,
      onPressed: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFFFF).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFFFFFF).withOpacity(0.18),
                      width: 1),
                ),
                child: Icon(icon, size: 18, color: const Color(0xFFFFFFFF)),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFFFFFFFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedListCard extends StatelessWidget {
  const _SuggestedListCard({
    required this.colors,
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  final _ApplePalette colors;
  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final bg = colors.isLight ? colors.surface : const Color(0xFF1C1C1E);
    final border =
        colors.separator.withValues(alpha: colors.isLight ? 0.35 : 0.22);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [colors.subtleShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF34C759),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(CupertinoIcons.sparkles,
                color: Color(0xFFFFFFFF), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.10,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            pressedOpacity: 0.55,
            onPressed: onAdd,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.isLight
                    ? const Color(0xFFF2F2F7)
                    : const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: border),
              ),
              child: const Icon(CupertinoIcons.add,
                  color: Color(0xFF34C759), size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeListItem {
  const _HomeListItem({
    required this.kind,
    required this.title,
    required this.icon,
    required this.iconBg,
    required this.count,
    required this.folderId,
    required this.trailingBadge,
  });

  final _ListKind kind;
  final String title;
  final IconData icon;
  final Color iconBg;
  final int count;
  final String folderId;
  final String? trailingBadge;
}

class _ListsCard extends StatelessWidget {
  const _ListsCard({
    required this.colors,
    required this.items,
    required this.onTap,
  });

  final _ApplePalette colors;
  final List<_HomeListItem> items;
  final ValueChanged<_HomeListItem> onTap;

  @override
  Widget build(BuildContext context) {
    return _AppleInsetGroupedList(
      colors: colors,
      children: [
        for (int i = 0; i < items.length; i++)
          _ListRow(
            colors: colors,
            item: items[i],
            onTap: () => onTap(items[i]),
          ),
      ],
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.colors,
    required this.item,
    required this.onTap,
  });

  final _ApplePalette colors;
  final _HomeListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      pressedOpacity: 0.55,
      onPressed: onTap,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.iconBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(item.icon, color: const Color(0xFFFFFFFF), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (item.trailingBadge != null) ...[
                  const SizedBox(width: 8),
                  Text(item.trailingBadge!,
                      style: const TextStyle(fontSize: 16)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${item.count}',
            style: TextStyle(
              color: colors.textSecondary,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              height: 1.05,
            ),
          ),
          const SizedBox(width: 8),
          Icon(CupertinoIcons.chevron_forward, color: colors.muted, size: 16),
        ],
      ),
    );
  }
}

class _FloatingAddButton extends StatelessWidget {
  const _FloatingAddButton({
    required this.color,
    required this.onTap,
  });

  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: Semantics(
        button: true,
        label: AppStrings.semAddSheet,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minSize: 0,
          pressedOpacity: 0.65,
          onPressed: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 22,
                    offset: Offset(0, 12)),
              ],
            ),
            child: const Icon(CupertinoIcons.add,
                color: Color(0xFFFFFFFF), size: 28),
          ),
        ),
      ),
    );
  }
}

// ------------------------- Apple UI primitives -------------------------

class _ApplePalette {
  _ApplePalette({required this.isLight});

  final bool isLight;

  Color get bg => isLight ? const Color(0xFFF5F5F7) : const Color(0xFF050509);

  Color get surface =>
      isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0E0E12);

  Color get group =>
      isLight ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);

  Color get separator =>
      isLight ? const Color(0x1F000000) : const Color(0x33FFFFFF);

  Color get textPrimary =>
      isLight ? const Color(0xFF0B0B0F) : const Color(0xFFF5F5F7);

  Color get textSecondary =>
      isLight ? const Color(0x990B0B0F) : const Color(0x99F5F5F7);

  Color get accent =>
      isLight ? const Color(0xFF111114) : const Color(0xFFF4F4F6);

  Color get muted =>
      isLight ? const Color(0x660B0B0F) : const Color(0x66F5F5F7);

  Color get navBarBg {
    // iOS-like translucent bar
    final base = isLight ? const Color(0xFFF9F9FB) : const Color(0xFF0B0B0D);
    return base.withValues(alpha: 0.92);
  }

  BoxShadow get subtleShadow => BoxShadow(
        color: isLight ? const Color(0x14000000) : const Color(0x22000000),
        blurRadius: 16,
        offset: const Offset(0, 8),
      );
}

class _AppleSectionCard extends StatelessWidget {
  const _AppleSectionCard({
    required this.colors,
    required this.child,
  });

  final _ApplePalette colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.separator),
        boxShadow: [colors.subtleShadow],
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _AppleInsetGroupedList extends StatelessWidget {
  const _AppleInsetGroupedList({
    required this.colors,
    required this.children,
  });

  final _ApplePalette colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.separator),
        boxShadow: [colors.subtleShadow],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Container(
                  height: 1, color: colors.separator.withValues(alpha: 0.75)),
          ],
        ],
      ),
    );
  }
}

class _AppleToast extends StatefulWidget {
  const _AppleToast({
    required this.message,
    required this.isLight,
  });

  final String message;
  final bool isLight;

  @override
  State<_AppleToast> createState() => _AppleToastState();
}

class _AppleToastState extends State<_AppleToast> {
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    // Fade in next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _opacity = 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.isLight ? const Color(0xEE111114) : const Color(0xEE0F0F12);
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 160),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000),
                blurRadius: 20,
                offset: Offset(0, 10)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          widget.message,
          style: const TextStyle(
              color: Color(0xFFF5F5F7), fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SegmentedScope extends StatelessWidget {
  const _SegmentedScope({
    required this.isLight,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  final bool isLight;
  final bool value;
  final ValueChanged<bool> onChanged;
  final _ApplePalette colors;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<bool>(
      groupValue: value,
      thumbColor: isLight ? colors.group : colors.surface,
      backgroundColor:
          isLight ? colors.group : colors.group.withValues(alpha: 0.35),
      onValueChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
      children: const {
        false: Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Text('Carpeta', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        true: Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Text('Todas', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      },
    );
  }
}

class _AppleEmptyState extends StatelessWidget {
  const _AppleEmptyState({
    required this.colors,
    required this.tab,
    required this.onNew,
    required this.onFolders,
    required this.isBusy,
  });

  final _ApplePalette colors;
  final _HomeTab tab;
  final Future<void> Function() onNew;
  final Future<void> Function() onFolders;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final title = tab == _HomeTab.trash ? 'Papelera vacía' : 'No hay planillas';
    final msg = tab == _HomeTab.trash
        ? 'Las planillas movidas a papelera aparecen acá durante un tiempo para poder recuperarlas.'
        : 'Creá tu primera hoja y empezá a trabajar. Si usás carpetas por mes, queda ordenado solo.';

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.separator),
        boxShadow: [colors.subtleShadow],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          Icon(
            tab == _HomeTab.trash
                ? CupertinoIcons.trash
                : CupertinoIcons.doc_text,
            size: 44,
            color: colors.accent.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (tab == _HomeTab.sheets)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton.filled(
                  onPressed: isBusy ? null : () => onNew(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: const Text('Nueva planilla'),
                ),
                const SizedBox(width: 10),
                _AppleOutlineButton(
                  onPressed: () => onFolders(),
                  colors: colors,
                  label: 'Carpetas',
                  icon: CupertinoIcons.folder,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AppleOutlineButton extends StatelessWidget {
  const _AppleOutlineButton({
    required this.onPressed,
    required this.colors,
    required this.label,
    required this.icon,
  });

  final VoidCallback onPressed;
  final _ApplePalette colors;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: colors.surface,
      borderRadius: BorderRadius.circular(12),
      pressedOpacity: 0.55,
      child: Row(
        children: [
          Icon(icon, size: 18, color: colors.accent),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: colors.textPrimary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CupertinoToggleRow extends StatelessWidget {
  const _CupertinoToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isLight = CupertinoTheme.of(context).brightness == Brightness.light;
    final pal = _ApplePalette(isLight: isLight);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.separator),
        color: pal.group.withValues(alpha: pal.isLight ? 0.75 : 0.35),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: pal.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: pal.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _CupertinoInfoBanner extends StatelessWidget {
  const _CupertinoInfoBanner({
    required this.icon,
    required this.title,
    required this.message,
    required this.isLight,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final pal = _ApplePalette(isLight: isLight);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: pal.accent.withValues(alpha: 0.08),
        border: Border.all(color: pal.accent.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: pal.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: pal.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(message,
                    style: TextStyle(
                        color: pal.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppleSheetRow extends StatelessWidget {
  const _AppleSheetRow({
    super.key,
    required this.colors,
    required this.meta,
    required this.note,
    required this.folderName,
    required this.fmt,
    required this.tab,
    required this.busy,
    required this.daysLeftInTrash,
    required this.onOpen,
    required this.onRename,
    required this.onExport,
    required this.onEditNote,
    required this.onMoveFolder,
    required this.onMoveToTrash,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final _ApplePalette colors;
  final SheetMeta meta;
  final String note;
  final String folderName;
  final String Function(DateTime) fmt;
  final _HomeTab tab;
  final bool busy;
  final int? daysLeftInTrash;

  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onEditNote;
  final VoidCallback onMoveFolder;
  final VoidCallback onMoveToTrash;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  bool get _recent {
    final now = DateTime.now();
    final d = meta.updatedAt.toLocal();
    final diff = now.difference(d);
    return diff.inHours < 12;
  }

  @override
  Widget build(BuildContext context) {
    final title = meta.title.isEmpty ? 'Planilla sin título' : meta.title;
    final subtitle = tab == _HomeTab.trash
        ? '${meta.rows} filas · ${fmt(meta.updatedAt)} · vence en ${daysLeftInTrash ?? 0} día(s)'
        : '${meta.rows} filas · ${fmt(meta.updatedAt)} · $folderName';

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      pressedOpacity: 0.55,
      onPressed: busy ? null : onOpen,
      onLongPress: busy ? null : onRename,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: colors.accent.withValues(alpha: 0.10),
              border: Border.all(color: colors.accent.withValues(alpha: 0.18)),
            ),
            alignment: Alignment.center,
            child: Icon(
              tab == _HomeTab.trash
                  ? CupertinoIcons.trash
                  : CupertinoIcons.doc_text,
              color: colors.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_recent && tab == _HomeTab.sheets)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: colors.accent.withValues(alpha: 0.12),
                          border: Border.all(
                              color: colors.accent.withValues(alpha: 0.18)),
                        ),
                        child: Text('Hoy',
                            style: TextStyle(
                                color: colors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary.withValues(alpha: 0.92),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const CupertinoActivityIndicator()
          else
            _SheetActionButton(
              colors: colors,
              tab: tab,
              onOpen: onOpen,
              onExport: onExport,
              onRename: onRename,
              onEditNote: onEditNote,
              onMoveFolder: onMoveFolder,
              onMoveToTrash: onMoveToTrash,
              onRestore: onRestore,
              onDeleteForever: onDeleteForever,
            ),
        ],
      ),
    );
  }
}

class _AppleSheetGridCard extends StatelessWidget {
  const _AppleSheetGridCard({
    required this.colors,
    required this.meta,
    required this.note,
    required this.folderName,
    required this.tab,
    required this.busy,
    required this.daysLeftInTrash,
    required this.fmt,
    required this.onOpen,
    required this.onRename,
    required this.onExport,
    required this.onEditNote,
    required this.onMoveFolder,
    required this.onMoveToTrash,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final _ApplePalette colors;
  final SheetMeta meta;
  final String note;
  final String folderName;
  final _HomeTab tab;
  final bool busy;
  final int? daysLeftInTrash;
  final String Function(DateTime) fmt;

  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onExport;
  final VoidCallback onEditNote;
  final VoidCallback onMoveFolder;
  final VoidCallback onMoveToTrash;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    final title = meta.title.isEmpty ? 'Planilla sin título' : meta.title;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.separator),
        boxShadow: [colors.subtleShadow],
      ),
      padding: const EdgeInsets.all(12),
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
                  style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2),
                ),
              ),
              if (busy)
                const CupertinoActivityIndicator()
              else
                _SheetActionButton(
                  colors: colors,
                  tab: tab,
                  onOpen: onOpen,
                  onExport: onExport,
                  onRename: onRename,
                  onEditNote: onEditNote,
                  onMoveFolder: onMoveFolder,
                  onMoveToTrash: onMoveToTrash,
                  onRestore: onRestore,
                  onDeleteForever: onDeleteForever,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tab == _HomeTab.trash
                ? '${meta.rows} filas · vence en ${daysLeftInTrash ?? 0} día(s)'
                : '${meta.rows} filas · $folderName',
            style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: colors.textSecondary.withValues(alpha: 0.92),
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
          ],
          const Spacer(),
          CupertinoButton.filled(
            onPressed: busy ? null : onOpen,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(tab == _HomeTab.trash ? 'Restaurar/Abrir' : 'Abrir'),
          ),
        ],
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({
    required this.colors,
    required this.tab,
    required this.onOpen,
    required this.onExport,
    required this.onRename,
    required this.onEditNote,
    required this.onMoveFolder,
    required this.onMoveToTrash,
    required this.onRestore,
    required this.onDeleteForever,
  });

  final _ApplePalette colors;
  final _HomeTab tab;

  final VoidCallback onOpen;
  final VoidCallback onExport;
  final VoidCallback onRename;
  final VoidCallback onEditNote;

  final VoidCallback onMoveFolder;
  final VoidCallback onMoveToTrash;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.semOpenSheetActions,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        minSize: 0,
        onPressed: () async {
          await showCupertinoModalPopup<void>(
            context: context,
            builder: (ctx) {
              final actions = <Widget>[];

              if (tab == _HomeTab.trash) {
                actions.addAll([
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onRestore();
                    },
                    child: const Text('Restaurar'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onExport();
                    },
                    child: const Text('Exportar XLSX'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onDeleteForever();
                    },
                    isDestructiveAction: true,
                    child: const Text('Eliminar definitivamente'),
                  ),
                ]);
              } else {
                actions.addAll([
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onOpen();
                    },
                    child: const Text('Abrir'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onExport();
                    },
                    child: const Text('Exportar XLSX'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onEditNote();
                    },
                    child: const Text('Mensaje destacado'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onMoveFolder();
                    },
                    child: const Text('Mover a carpeta'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onRename();
                    },
                    child: const Text('Renombrar'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onMoveToTrash();
                    },
                    isDestructiveAction: true,
                    child: const Text('Mover a papelera'),
                  ),
                ]);
              }

              return CupertinoActionSheet(
                actions: actions,
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(ctx).pop(),
                  isDefaultAction: true,
                  child: const Text('Cancelar'),
                ),
              );
            },
          );
        },
        child: Icon(CupertinoIcons.ellipsis, color: colors.muted, size: 20),
      ),
    );
  }
}

// ---------------- Folder primitives ----------------

class _Folder {
  const _Folder({
    required this.id,
    required this.name,
    required this.createdAtMs,
  });

  final String id;
  final String name;
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAtMs': createdAtMs,
      };

  factory _Folder.fromJson(Map<String, dynamic> j) {
    return _Folder(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      createdAtMs: (j['createdAtMs'] is num)
          ? (j['createdAtMs'] as num).toInt()
          : int.tryParse('${j['createdAtMs']}') ?? 0,
    );
  }

  _Folder copyWith({String? name}) => _Folder(
        id: id,
        name: name ?? this.name,
        createdAtMs: createdAtMs,
      );
}

// ---------------- Folder manager page (Cupertino) ----------------

class _FolderManagerPage extends StatefulWidget {
  const _FolderManagerPage({
    required this.isLight,
    required this.folders,
    required this.getCount,
    required this.onCreate,
    required this.onRename,
    required this.onDelete,
  });

  final bool isLight;
  final List<_Folder> folders;
  final int Function(String folderId) getCount;

  final Future<_Folder?> Function() onCreate;
  final Future<_Folder?> Function(_Folder folder) onRename;
  final Future<void> Function(_Folder folder) onDelete;

  @override
  State<_FolderManagerPage> createState() => _FolderManagerPageState();
}

class _FolderManagerPageState extends State<_FolderManagerPage> {
  @override
  Widget build(BuildContext context) {
    final pal = _ApplePalette(isLight: widget.isLight);
    final folders = List<_Folder>.from(widget.folders)
      ..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

    return CupertinoPageScaffold(
      backgroundColor: pal.bg,
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Carpetas'),
        backgroundColor: pal.navBarBg,
        border: Border(bottom: BorderSide(color: pal.separator)),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            await widget.onCreate();
            if (!mounted) return;
            setState(() {});
          },
          child: Icon(CupertinoIcons.add, color: pal.accent),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: folders.isEmpty
              ? _AppleSectionCard(
                  colors: pal,
                  child: Text(
                    'No hay carpetas creadas todavía.',
                    style: TextStyle(
                        color: pal.textSecondary, fontWeight: FontWeight.w600),
                  ),
                )
              : _AppleInsetGroupedList(
                  colors: pal,
                  children: [
                    for (final f in folders)
                      _FolderRow(
                        pal: pal,
                        folder: f,
                        count: widget.getCount(f.id),
                        onRename: () async {
                          await widget.onRename(f);
                          if (!mounted) return;
                          setState(() {});
                        },
                        onDelete: () async {
                          await widget.onDelete(f);
                          if (!mounted) return;
                          setState(() {});
                        },
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.pal,
    required this.folder,
    required this.count,
    required this.onRename,
    required this.onDelete,
  });

  final _ApplePalette pal;
  final _Folder folder;
  final int count;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  static String _fmtFolderCreated(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      pressedOpacity: 0.55,
      onPressed: () async {
        await showCupertinoModalPopup<void>(
          context: context,
          builder: (ctx) => CupertinoActionSheet(
            title: Text(folder.name),
            message: Text(
                '$count planilla(s) · creada ${_fmtFolderCreated(folder.createdAtMs)}'),
            actions: [
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onRename();
                },
                child: const Text('Renombrar'),
              ),
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onDelete();
                },
                isDestructiveAction: true,
                child: const Text('Eliminar'),
              ),
            ],
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
          ),
        );
      },
      child: Row(
        children: [
          Icon(CupertinoIcons.folder, color: pal.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(folder.name,
                    style: TextStyle(
                        color: pal.textPrimary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  '$count planilla(s) · creada ${_fmtFolderCreated(folder.createdAtMs)}',
                  style: TextStyle(
                      color: pal.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Icon(CupertinoIcons.chevron_forward, color: pal.muted, size: 16),
        ],
      ),
    );
  }
}

// ---------------- Prompt helper models ----------------

class _PromptInfo {
  const _PromptInfo({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}

class _PromptExtraAction {
  const _PromptExtraAction({
    required this.label,
    required this.value,
    this.isDestructive = false,
  });

  final String label;
  final String value;
  final bool isDestructive;
}

class _EngineProbeResult {
  const _EngineProbeResult({
    required this.ok,
    required this.message,
    required this.resolvedBase,
  });

  final bool ok;
  final String message;
  final String? resolvedBase;
}

class _MailSettingsResult {
  const _MailSettingsResult({
    required this.email,
    required this.autoSend,
    required this.engineMode,
    required this.manualBaseUrl,
  });

  final String email;
  final bool autoSend;
  final String engineMode;
  final String manualBaseUrl;
}

// ---------------- Compat: Color.withValues(alpha: ...) ----------------
// Si tu Flutter ya lo tiene nativo, esta extensión no molesta: el miembro real gana.
extension _ColorWithValuesCompat on Color {
  Color withValues({double? alpha}) {
    if (alpha == null) return this;
    final a = (alpha.clamp(0.0, 1.0) * 255).round().clamp(0, 255);
    return withAlpha(a);
  }
}
