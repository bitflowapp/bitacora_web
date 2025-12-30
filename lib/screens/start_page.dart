// lib/screens/start_page.dart
// StartPage (BitFlow) — Home “100% Apple” (Cupertino-first), robusto y vendible.
// Cambios clave vs versión Material:
// - Sin FAB, sin PopupMenuButton, sin SnackBar: iOS UX real (Large Title + ActionSheets + Toast overlay).
// - Segmented control para Planillas/Papelera y alcance de búsqueda.
// - Carpetas: selector iOS (ActionSheet) + gestión en página Cupertino.
// - Confirmaciones y ediciones: CupertinoAlertDialog + CupertinoTextField.
// - Pull-to-refresh: CupertinoSliverRefreshControl.
// - Listas “inset grouped” (contenedor + separadores finos), ripple eliminado.
//
// Dependencias:
//   - flutter_animate
//   - shared_preferences
//
// Notas de arquitectura:
// - Carpetas, notas, createdAt y papelera se guardan en SharedPreferences para no tocar SheetStore.
// - Eliminación: mueve a Papelera (soft-delete). "Eliminar definitivamente" recién llama a SheetStore.delete.
// - TTL papelera: _trashTtlDays (por defecto 14 días).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, Border, BorderRadius, BoxDecoration, BoxShadow, Offset, BoxConstraints;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../workers/json_worker.dart';
import '../services/sheet_store.dart';
import '../services/export_xlsx_service.dart';
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
enum _HomeTab { sheets, trash }

class _StartPageState extends State<StartPage> {
  // --------------------- Data ---------------------
  List<SheetMeta> _items = <SheetMeta>[];
  String _q = '';
  bool _searchAll = false;
  _ViewMode _view = _ViewMode.list;
  _SortMode _sort = _SortMode.updatedDesc;
  _HomeTab _tab = _HomeTab.sheets;

  // Carpeta seleccionada (solo aplica en _HomeTab.sheets)
  String _selectedFolderId = ''; // '' = Raíz

  // --------------------- Preferences (correo destino) ---------------------
  static const String _kPrefDefaultEmail = 'bitflow.default_email';
  static const String _kPrefAutoSend = 'bitflow.auto_send';

  bool _prefsLoaded = false;
  String _defaultEmail = '';
  bool _autoSend = true;

  // --------------------- Organization state (folders, notes, trash, createdAt) ---------------------
  static const int _trashTtlDays = 14;

  static const String _kPrefFolders = 'bitflow.folders.v1';
  static const String _kPrefSheetFolder = 'bitflow.sheet_folder.v1';
  static const String _kPrefSheetCreatedAt = 'bitflow.sheet_created_at.v1';
  static const String _kPrefSheetNotes = 'bitflow.sheet_notes.v1';
  static const String _kPrefTrash = 'bitflow.trash.v1';

  bool _orgLoaded = false;

  final List<_Folder> _folders = <_Folder>[];
  final Map<String, String> _sheetFolder = <String, String>{}; // sheetId -> folderId
  final Map<String, int> _sheetCreatedAtMs = <String, int>{}; // sheetId -> ms
  final Map<String, String> _sheetNotes = <String, String>{}; // sheetId -> note
  final Map<String, int> _trashDeletedAtMs = <String, int>{}; // sheetId -> deletedAtMs

  // --------------------- Busy state ---------------------
  bool _busy = false;
  String? _busySheetId;

  // --------------------- Controllers ---------------------
  late final TextEditingController _searchEC;

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

  // --------------------- Load/Save Prefs ---------------------

  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      final email = (p.getString(_kPrefDefaultEmail) ?? '').trim();
      final autoSend = p.getBool(_kPrefAutoSend) ?? true;

      if (!mounted) return;
      setState(() {
        _defaultEmail = email;
        _autoSend = autoSend;
        _prefsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _prefsLoaded = true);
    }
  }

  Future<void> _savePrefs({
    required String email,
    required bool autoSend,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPrefDefaultEmail, email.trim());
    await p.setBool(_kPrefAutoSend, autoSend);

    if (!mounted) return;
    setState(() {
      _defaultEmail = email.trim();
      _autoSend = autoSend;
      _prefsLoaded = true;
    });
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
          foldersJson.map((e) => _Folder.fromJson(e)).where((f) => f.id.isNotEmpty),
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
    // FIX CRÍTICO: si falla SheetStore.delete, NO removemos metadata.
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
        // Se mantiene en papelera para no “revivir” datos inconsistentes.
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
        message: 'Para abrir y editar, primero hay que restaurar la planilla. ¿Restaurar ahora?',
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
      message: 'Se podrá recuperar durante $_trashTtlDays días. ¿Querés continuar?',
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
        fileName: name, // sin “.xlsx”
        headers: parsed.headers,
        rows: parsed.rows,
      );

      if (!mounted) return;
      _toast('Exportado como $name.xlsx');

      // Estado de producto (sin fragilidad): avisamos configuración.
      if (_autoSend && _defaultEmail.isNotEmpty) {
        _toast('Auto-envío activo: destino ${_defaultEmail.trim()}');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('Error al exportar XLSX: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _busySheetId = null;
      });
    }
  }

  // --------------------- Notes (“mensaje destacado”) ---------------------

  Future<void> _editNote(SheetMeta m) async {
    final current = (_sheetNotes[m.id] ?? '').trim();

    final result = await _promptMultilineCupertino(
      title: 'Mensaje destacado',
      initialValue: current,
      placeholder: 'Ej: “Enviar a cliente hoy 18:00” / “WP: revisar medición 3”',
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

    final folders = List<_Folder>.from(_folders)..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

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
      message: 'Las planillas vuelven a “Raíz”. ¿Eliminar “${folder.name}”?',
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
        message: 'Ejemplos: “$suggested”, “Septiembre 2026”, “Obra X”. Un solo nivel, simple y ordenado.',
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

    final folders = List<_Folder>.from(_folders)..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));
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

  // --------------------- Mail Settings UI ---------------------

  Future<void> _openMailSettings() async {
    final emailEC = TextEditingController(text: _defaultEmail);
    bool autoSend = _autoSend;

    final result = await showCupertinoDialog<_MailSettingsResult?>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final email = emailEC.text.trim();
            final emailOk = email.isEmpty || _looksLikeEmail(email);

            return CupertinoAlertDialog(
              title: const Text('Correo destino'),
              content: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    _CupertinoInfoBanner(
                      icon: CupertinoIcons.paperplane,
                      title: 'Entregables automáticos',
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                            color: widget.isLight ? const Color(0xFFB00020) : const Color(0xFFFF6B6B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    _CupertinoToggleRow(
                      title: 'Auto-envío al exportar',
                      subtitle: 'Activa la automatización cuando tu producto lo ejecute.',
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
                    if (email.isNotEmpty && !_looksLikeEmail(email)) return;
                    Navigator.of(dialogContext).pop(_MailSettingsResult(email: email, autoSend: autoSend));
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

    if (result == null) return;
    await _savePrefs(email: result.email, autoSend: result.autoSend);

    if (!mounted) return;
    _toast(_defaultEmail.isEmpty ? 'Correo destino limpiado.' : 'Correo destino guardado.');
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
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+\.[^\s@]+$'); // fallback extra, se corrige abajo
    // Mejor: patrón simple, sin ser policía.
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                onPressed: () => Navigator.of(dialogContext).pop(extraAction.value),
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
      if (d.year == now.year && d.month == now.month && d.day == now.day) today++;
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
    final sView = _statsView;

    final folderLabel = _tab == _HomeTab.trash ? 'Papelera' : _folderName(_selectedFolderId);

    final title = _tab == _HomeTab.trash ? 'Papelera' : 'BitFlow';

    return CupertinoPageScaffold(
      backgroundColor: colors.bg,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: colors.textPrimary,
                ),
              ),
              backgroundColor: colors.navBarBg,
              border: Border(bottom: BorderSide(color: colors.separator)),
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: widget.onToggleTheme,
                child: Icon(
                  isLight ? CupertinoIcons.moon_stars : CupertinoIcons.sun_max,
                  color: colors.accent,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: (_busy || _tab == _HomeTab.trash) ? null : _newSheet,
                    child: Icon(CupertinoIcons.add_circled_solid, color: (_busy || _tab == _HomeTab.trash) ? colors.muted : colors.accent),
                  ),
                  const SizedBox(width: 6),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _tab == _HomeTab.trash ? null : _openFolderPicker,
                    child: Icon(CupertinoIcons.folder, color: _tab == _HomeTab.trash ? colors.muted : colors.accent),
                  ),
                  const SizedBox(width: 6),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _openMailSettings,
                    child: Icon(CupertinoIcons.gear, color: colors.accent),
                  ),
                  const SizedBox(width: 6),
                  _SortButton(
                    isLight: isLight,
                    current: _sort,
                    onChanged: (v) => setState(() => _sort = v),
                    colors: colors,
                  ),
                  const SizedBox(width: 2),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      await showCupertinoModalPopup<void>(
                        context: context,
                        builder: (ctx) => CupertinoActionSheet(
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
                        ),
                      );
                    },
                    child: Icon(
                      _view == _ViewMode.list ? CupertinoIcons.square_list : CupertinoIcons.rectangle_grid_2x2,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
            ),

            // Pull to refresh (iOS)
            CupertinoSliverRefreshControl(
              onRefresh: () async => _reload(),
            ),

            // Segmented: Planillas / Papelera
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: _AppleSectionCard(
                  colors: colors,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SegmentedTabs(
                        isLight: isLight,
                        value: _tab,
                        onChanged: (v) {
                          setState(() {
                            _tab = v;
                            if (v == _HomeTab.trash) {
                              _q = _q; // mantiene búsqueda
                            }
                          });
                        },
                        colors: colors,
                      ),
                      const SizedBox(height: 12),

                      // Estado compacto (carpeta/correo/autosend)
                      Row(
                        children: [
                          Expanded(
                            child: _StatusPill(
                              colors: colors,
                              icon: _tab == _HomeTab.trash ? CupertinoIcons.trash : CupertinoIcons.folder,
                              title: _tab == _HomeTab.trash ? 'Papelera' : 'Carpeta',
                              value: folderLabel,
                              onTap: _tab == _HomeTab.trash ? null : _openFolderPicker,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatusPill(
                              colors: colors,
                              icon: CupertinoIcons.mail,
                              title: 'Correo',
                              value: _prefsLoaded
                                  ? (_defaultEmail.isEmpty ? 'Sin configurar' : _defaultEmail)
                                  : 'Cargando…',
                              onTap: _openMailSettings,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _CupertinoToggleRow(
                        title: 'Auto-envío',
                        subtitle: _defaultEmail.isEmpty ? 'Configura correo para usarlo.' : 'Listo para automatización al exportar.',
                        value: _autoSend,
                        onChanged: (v) async {
                          setState(() => _autoSend = v);
                          await _savePrefs(email: _defaultEmail, autoSend: v);
                        },
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 220.ms).move(begin: const Offset(0, 6)),
              ),
            ),

            // KPIs
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _AppleKpis(
                  colors: colors,
                  tab: _tab,
                  viewCount: sView.total,
                  todayAll: sAll.today,
                  totalRowsAll: sAll.totalRows,
                ).animate().fadeIn(duration: 220.ms, delay: 50.ms),
              ),
            ),

            // Search + scope
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
                        placeholder: 'Buscar por título o mensaje destacado…',
                      ),
                      if (_tab == _HomeTab.sheets) ...[
                        const SizedBox(height: 10),
                        _SegmentedScope(
                          isLight: isLight,
                          value: _searchAll,
                          onChanged: (v) => setState(() => _searchAll = v),
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
                      : (_searchAll
                      ? 'Mostrando ${data.length} (buscando en todas)'
                      : 'Mostrando ${data.length} en “${_folderName(_selectedFolderId)}”'),
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
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
                          note: (_sheetNotes[data[i].id] ?? '').trim(),
                          folderName: _folderName(_sheetFolder[data[i].id] ?? ''),
                          fmt: _fmt,
                          tab: _tab,
                          busy: _busy && _busySheetId == data[i].id,
                          daysLeftInTrash: _tab == _HomeTab.trash ? _daysLeftInTrash(data[i].id) : null,
                          onOpen: () => _open(data[i]),
                          onRename: () => _rename(data[i]),
                          onExport: () => _exportSheet(data[i]),
                          onEditNote: () => _editNote(data[i]),
                          onMoveFolder: () => _moveSheetToFolder(data[i]),
                          onMoveToTrash: () => _moveToTrash(data[i]),
                          onRestore: () => _restoreFromTrash(data[i].id),
                          onDeleteForever: () => _deleteForever(data[i]),
                        ).animate(delay: (30 + i * 20).ms).fadeIn(duration: 180.ms).move(begin: const Offset(0, 4)),
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
                        folderName: _folderName(_sheetFolder[m.id] ?? ''),
                        tab: _tab,
                        busy: _busy && _busySheetId == m.id,
                        daysLeftInTrash: _tab == _HomeTab.trash ? _daysLeftInTrash(m.id) : null,
                        fmt: _fmt,
                        onOpen: () => _open(m),
                        onRename: () => _rename(m),
                        onExport: () => _exportSheet(m),
                        onEditNote: () => _editNote(m),
                        onMoveFolder: () => _moveSheetToFolder(m),
                        onMoveToTrash: () => _moveToTrash(m),
                        onRestore: () => _restoreFromTrash(m.id),
                        onDeleteForever: () => _deleteForever(m),
                      ).animate().fadeIn(duration: 200.ms, delay: 30.ms);
                    },
                    childCount: data.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.35,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------- JSON helpers ---------------------

  List<Map<String, dynamic>> _safeJsonDecodeList(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is List) {
        return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
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

// ------------------------- Apple UI primitives -------------------------

class _ApplePalette {
  _ApplePalette({required this.isLight});

  final bool isLight;

  Color get bg => isLight ? const Color(0xFFF5F5F7) : const Color(0xFF050509);

  Color get surface => isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0E0E12);

  Color get group => isLight ? const Color(0xFFF2F2F7) : const Color(0xFF1C1C1E);

  Color get separator => isLight ? const Color(0x1F000000) : const Color(0x33FFFFFF);

  Color get textPrimary => isLight ? const Color(0xFF0B0B0F) : const Color(0xFFF5F5F7);

  Color get textSecondary => isLight ? const Color(0x990B0B0F) : const Color(0x99F5F5F7);

  Color get accent => isLight ? const Color(0xFF007AFF) : const Color(0xFF0A84FF);

  Color get muted => isLight ? const Color(0x660B0B0F) : const Color(0x66F5F5F7);

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
              Container(height: 1, color: colors.separator.withValues(alpha: 0.75)),
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
    final bg = widget.isLight ? const Color(0xEE111114) : const Color(0xEE0F0F12);
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 160),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 10)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          widget.message,
          style: const TextStyle(color: Color(0xFFF5F5F7), fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.isLight,
    required this.value,
    required this.onChanged,
    required this.colors,
  });

  final bool isLight;
  final _HomeTab value;
  final ValueChanged<_HomeTab> onChanged;
  final _ApplePalette colors;

  @override
  Widget build(BuildContext context) {
    return CupertinoSlidingSegmentedControl<_HomeTab>(
      groupValue: value,
      thumbColor: isLight ? colors.group : colors.surface,
      backgroundColor: isLight ? colors.group : colors.group.withValues(alpha: 0.35),
      onValueChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
      children: const {
        _HomeTab.sheets: Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Text('Planillas', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        _HomeTab.trash: Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Text('Papelera', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      },
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
      backgroundColor: isLight ? colors.group : colors.group.withValues(alpha: 0.35),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.colors,
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final _ApplePalette colors;
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.group.withValues(alpha: colors.isLight ? 0.75 : 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.separator),
      ),
      child: CupertinoButton(
        onPressed: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        pressedOpacity: 0.55,
        child: Row(
          children: [
            Icon(icon, color: colors.accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(CupertinoIcons.chevron_down, color: colors.muted, size: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppleKpis extends StatelessWidget {
  const _AppleKpis({
    required this.colors,
    required this.tab,
    required this.viewCount,
    required this.todayAll,
    required this.totalRowsAll,
  });

  final _ApplePalette colors;
  final _HomeTab tab;
  final int viewCount;
  final int todayAll;
  final int totalRowsAll;

  Widget _kpi(String title, String value, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.separator),
        boxShadow: [colors.subtleShadow],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colors.accent.withValues(alpha: 0.10),
              border: Border.all(color: colors.accent.withValues(alpha: 0.16)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: colors.accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _kpi(tab == _HomeTab.trash ? 'En papelera' : 'En vista', '$viewCount', tab == _HomeTab.trash ? CupertinoIcons.trash : CupertinoIcons.folder),
      _kpi('Actualizadas hoy', '$todayAll', CupertinoIcons.bolt),
      _kpi('Filas (total)', '$totalRowsAll', CupertinoIcons.table),
    ];

    return LayoutBuilder(
      builder: (_, cons) {
        final w = cons.maxWidth;
        final cols = w >= 980 ? 3 : w >= 620 ? 2 : 1;

        if (cols == 1) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: i == children.length - 1 ? 0 : 10),
                  child: children[i],
                ),
            ],
          );
        }

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final child in children)
              SizedBox(
                width: cols == 2 ? (w - 10) / 2 : (w - 20) / 3,
                child: child,
              ),
          ],
        );
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
            tab == _HomeTab.trash ? CupertinoIcons.trash : CupertinoIcons.doc_text,
            size: 44,
            color: colors.accent.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
          const SizedBox(height: 6),
          Text(msg, textAlign: TextAlign.center, style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          if (tab == _HomeTab.sheets)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton.filled(
                  onPressed: isBusy ? null : () => onNew(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          Text(label, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
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
                Text(title, style: TextStyle(color: pal.textPrimary, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: pal.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
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
                Text(title, style: TextStyle(color: pal.textPrimary, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: pal.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
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
              tab == _HomeTab.trash ? CupertinoIcons.trash : CupertinoIcons.doc_text,
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
                        style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_recent && tab == _HomeTab.sheets)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          color: colors.accent.withValues(alpha: 0.12),
                          border: Border.all(color: colors.accent.withValues(alpha: 0.18)),
                        ),
                        child: Text('Hoy', style: TextStyle(color: colors.accent, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    note,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.92), fontSize: 12, fontWeight: FontWeight.w800),
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
                  style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w900, letterSpacing: -0.2),
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
            style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.92), fontSize: 12, fontWeight: FontWeight.w800),
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
    return CupertinoButton(
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
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.isLight,
    required this.current,
    required this.onChanged,
    required this.colors,
  });

  final bool isLight;
  final _SortMode current;
  final ValueChanged<_SortMode> onChanged;
  final _ApplePalette colors;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () async {
        await showCupertinoModalPopup<void>(
          context: context,
          builder: (ctx) {
            return CupertinoActionSheet(
              title: const Text('Ordenar'),
              actions: [
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onChanged(_SortMode.updatedDesc);
                  },
                  isDefaultAction: current == _SortMode.updatedDesc,
                  child: const Text('Recientes'),
                ),
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onChanged(_SortMode.titleAsc);
                  },
                  isDefaultAction: current == _SortMode.titleAsc,
                  child: const Text('Título (A–Z)'),
                ),
                CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onChanged(_SortMode.rowsDesc);
                  },
                  isDefaultAction: current == _SortMode.rowsDesc,
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
      },
      child: Icon(CupertinoIcons.sort_down, color: colors.accent),
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
      createdAtMs: (j['createdAtMs'] is num) ? (j['createdAtMs'] as num).toInt() : int.tryParse('${j['createdAtMs']}') ?? 0,
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
    final folders = List<_Folder>.from(widget.folders)..sort((a, b) => b.createdAtMs.compareTo(a.createdAtMs));

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
              style: TextStyle(color: pal.textSecondary, fontWeight: FontWeight.w600),
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
            message: Text('$count planilla(s) · creada ${_fmtFolderCreated(folder.createdAtMs)}'),
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
                Text(folder.name, style: TextStyle(color: pal.textPrimary, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(
                  '$count planilla(s) · creada ${_fmtFolderCreated(folder.createdAtMs)}',
                  style: TextStyle(color: pal.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
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

class _MailSettingsResult {
  const _MailSettingsResult({
    required this.email,
    required this.autoSend,
  });

  final String email;
  final bool autoSend;
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
