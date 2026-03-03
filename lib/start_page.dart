// lib/start_page.dart
// StartPage (BitFlow) - Home "100% Apple" (Cupertino-first), robusto y vendible.
//
// UPDATE (menu estilo Reminders iOS):
// - Agrega dashboard superior: tarjetas Hoy/Programados/Todos/Con indicador/Terminados.
// - Agrega Lista sugerida + Mis listas (Raiz + Carpetas + Papelera).
// - Barra superior en píldora (Buscar / Nuevo / Más) como Reminders.
// - Botón flotante iOS (+) abajo a la derecha (NO Material FAB).
//
// FIX ENGINE (apunta al puerto):
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

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show
        kIsWeb,
        kDebugMode,
        defaultTargetPlatform,
        TargetPlatform,
        debugPrint,
        visibleForTesting;
import 'theme/app_theme.dart';
import 'package:flutter/material.dart'
    show
        Colors,
        ColorScheme,
        Border,
        BorderRadius,
        BoxDecoration,
        BoxShadow,
        Offset,
        BoxConstraints,
        Switch,
        PageView,
        PageController,
        Curves,
        Theme,
        Material,
        IconButton,
        Ink,
        InkWell,
        MaterialPageRoute,
        LicensePage,
        ModalRoute,
        showModalBottomSheet,
        showDialog;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';

import 'core/app_error.dart';
import 'ui/ui.dart';
import 'workers/json_worker.dart';
import 'services/app_error_reporter.dart';
import 'services/app_update_service.dart';
import 'services/app_config.dart';
import 'services/engine_api.dart';
import 'services/engine_config.dart';
import 'services/export_flow_outcome.dart';
import 'services/sheet_store.dart';
import 'services/web_capabilities.dart';
import 'models/cell_ref.dart';
import 'models/cell_meta.dart';
import 'models/table_state.dart';
import 'services/export_xlsx_service.dart';
import 'services/build_info.dart';
import 'services/force_update_service.dart';
import 'services/attachment_store.dart';
import 'services/audio_storage_service.dart';
import 'services/audio_service.dart';
import 'screens/about_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/spreadsheet_agent_screen.dart';
import 'screens/terms_screen.dart';
import 'services/auth_service.dart';
import 'services/runtime_flags.dart';
import 'widgets/command_palette.dart';

const bool _kShowDebugBadge =
    bool.fromEnvironment('SHOW_DEBUG_BADGE', defaultValue: false) ||
        bool.fromEnvironment('SHOW_BUILD_BADGE', defaultValue: false);

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

enum _DailyFocusTab { recents, favorites }

enum _CreateSheetChoice {
  blank,
  plantilla,
  resistividades,
  inventario,
  checklist,
}

class _PackColumnSpec {
  const _PackColumnSpec({
    required this.label,
    required this.type,
    this.required = false,
    this.enumValues = const <String>[],
    this.numberMin,
    this.numberMax,
    this.defaultValue,
  });

  final String label;
  final String type;
  final bool required;
  final List<String> enumValues;
  final double? numberMin;
  final double? numberMax;
  final String? defaultValue;
}

class _PackViewPreset {
  const _PackViewPreset({
    required this.name,
    this.statusValue,
    this.textContains,
  });

  final String name;
  final String? statusValue;
  final String? textContains;
}

class _PackTemplateSpec {
  const _PackTemplateSpec({
    required this.id,
    required this.pack,
    required this.name,
    required this.description,
    required this.icon,
    required this.tags,
    required this.columns,
    required this.views,
    this.workflowReview = false,
  });

  final String id;
  final String pack;
  final String name;
  final String description;
  final IconData icon;
  final List<String> tags;
  final List<_PackColumnSpec> columns;
  final List<_PackViewPreset> views;
  final bool workflowReview;
}

class _StartPageOperationCancelled implements Exception {
  const _StartPageOperationCancelled();
}

class _StartPageState extends State<StartPage> {
  static const String _kPrefSavedViews = 'bitflow.editor.saved_views.v1';
  static const List<_PackTemplateSpec> _commercialTemplates =
      <_PackTemplateSpec>[
    _PackTemplateSpec(
      id: 'campo_inspeccion_general',
      pack: 'Campo/Inspeccion',
      name: 'Inspeccion general',
      description: 'Checklist de campo con estados y responsables.',
      icon: CupertinoIcons.doc_text_search,
      tags: <String>['Campo', 'Control', 'Rapido'],
      workflowReview: true,
      columns: <_PackColumnSpec>[
        _PackColumnSpec(label: 'Fecha', type: 'date', required: true),
        _PackColumnSpec(label: 'Estado', type: 'status', enumValues: <String>[
          'Pendiente',
          'En progreso',
          'Completado',
          'Urgente'
        ]),
        _PackColumnSpec(label: 'Sector', type: 'text', required: true),
        _PackColumnSpec(label: 'Hallazgo', type: 'text', required: true),
        _PackColumnSpec(label: 'Responsable', type: 'text'),
      ],
      views: <_PackViewPreset>[
        _PackViewPreset(name: 'Campo'),
        _PackViewPreset(name: 'Revision', statusValue: 'Pendiente'),
        _PackViewPreset(name: 'Urgentes', statusValue: 'Urgente'),
      ],
    ),
    _PackTemplateSpec(
      id: 'campo_checklist_seguridad',
      pack: 'Campo/Inspeccion',
      name: 'Checklist seguridad',
      description: 'Verificacion de seguridad por item y fecha.',
      icon: CupertinoIcons.shield,
      tags: <String>['Seguridad', 'Checklist', 'Cumplimiento'],
      workflowReview: true,
      columns: <_PackColumnSpec>[
        _PackColumnSpec(label: 'Fecha', type: 'date', required: true),
        _PackColumnSpec(label: 'Item', type: 'text', required: true),
        _PackColumnSpec(
            label: 'Estado',
            type: 'status',
            enumValues: <String>['Pendiente', 'OK', 'No cumple', 'Urgente']),
        _PackColumnSpec(label: 'Evidencia', type: 'text'),
        _PackColumnSpec(label: 'Observacion', type: 'text'),
      ],
      views: <_PackViewPreset>[
        _PackViewPreset(name: 'Campo'),
        _PackViewPreset(name: 'Revision', statusValue: 'Pendiente'),
        _PackViewPreset(name: 'Urgentes', statusValue: 'Urgente'),
      ],
    ),
    _PackTemplateSpec(
      id: 'campo_mantenimiento_rapido',
      pack: 'Campo/Inspeccion',
      name: 'Mantenimiento rapido',
      description: 'Tareas de mantenimiento con proxima fecha.',
      icon: CupertinoIcons.wrench,
      tags: <String>['Mantenimiento', 'Equipo', 'Servicio'],
      columns: <_PackColumnSpec>[
        _PackColumnSpec(label: 'Fecha', type: 'date', required: true),
        _PackColumnSpec(label: 'Equipo', type: 'text', required: true),
        _PackColumnSpec(label: 'Estado', type: 'status', enumValues: <String>[
          'Pendiente',
          'En progreso',
          'Completado',
          'Urgente'
        ]),
        _PackColumnSpec(label: 'Proxima fecha', type: 'date'),
        _PackColumnSpec(label: 'Observacion', type: 'text'),
      ],
      views: <_PackViewPreset>[
        _PackViewPreset(name: 'Campo'),
        _PackViewPreset(name: 'Revision', statusValue: 'Pendiente'),
        _PackViewPreset(name: 'Urgentes', statusValue: 'Urgente'),
      ],
    ),
    _PackTemplateSpec(
      id: 'obra_avance_diario',
      pack: 'Obra/Avance',
      name: 'Avance diario',
      description: 'Seguimiento de frente de obra y porcentaje.',
      icon: CupertinoIcons.building_2_fill,
      tags: <String>['Obra', 'Avance', 'Diario'],
      workflowReview: true,
      columns: <_PackColumnSpec>[
        _PackColumnSpec(label: 'Fecha', type: 'date', required: true),
        _PackColumnSpec(label: 'Frente', type: 'text', required: true),
        _PackColumnSpec(
            label: '% Avance', type: 'number', numberMin: 0, numberMax: 100),
        _PackColumnSpec(label: 'Estado', type: 'status', enumValues: <String>[
          'Pendiente',
          'En progreso',
          'Completado',
          'Urgente'
        ]),
        _PackColumnSpec(label: 'Responsable', type: 'text'),
      ],
      views: <_PackViewPreset>[
        _PackViewPreset(name: 'Campo'),
        _PackViewPreset(name: 'Revision', statusValue: 'Pendiente'),
        _PackViewPreset(name: 'Urgentes', statusValue: 'Urgente'),
      ],
    ),
    _PackTemplateSpec(
      id: 'obra_control_materiales',
      pack: 'Obra/Avance',
      name: 'Control de materiales',
      description: 'Ingreso y uso de materiales por jornada.',
      icon: CupertinoIcons.cube_box_fill,
      tags: <String>['Materiales', 'Stock', 'Obra'],
      columns: <_PackColumnSpec>[
        _PackColumnSpec(label: 'Fecha', type: 'date', required: true),
        _PackColumnSpec(label: 'Material', type: 'text', required: true),
        _PackColumnSpec(
            label: 'Cantidad', type: 'number', required: true, numberMin: 0),
        _PackColumnSpec(label: 'Unidad', type: 'text', defaultValue: 'u'),
        _PackColumnSpec(
            label: 'Estado',
            type: 'status',
            enumValues: <String>['Pendiente', 'En progreso', 'Completado']),
      ],
      views: <_PackViewPreset>[
        _PackViewPreset(name: 'Campo'),
        _PackViewPreset(name: 'Revision', statusValue: 'Pendiente'),
        _PackViewPreset(name: 'Urgentes', textContains: 'faltante'),
      ],
    ),
    _PackTemplateSpec(
      id: 'obra_partes_trabajo',
      pack: 'Obra/Avance',
      name: 'Partes de trabajo',
      description: 'Parte diario por OT, actividad y horas.',
      icon: CupertinoIcons.doc_append,
      tags: <String>['Parte', 'OT', 'Horas'],
      workflowReview: true,
      columns: <_PackColumnSpec>[
        _PackColumnSpec(label: 'OT ID', type: 'text', required: true),
        _PackColumnSpec(label: 'Fecha', type: 'date', required: true),
        _PackColumnSpec(label: 'Actividad', type: 'text', required: true),
        _PackColumnSpec(label: 'Horas', type: 'number', numberMin: 0),
        _PackColumnSpec(
            label: 'Estado',
            type: 'status',
            enumValues: <String>['Pendiente', 'En progreso', 'Completado']),
      ],
      views: <_PackViewPreset>[
        _PackViewPreset(name: 'Campo'),
        _PackViewPreset(name: 'Revision', statusValue: 'Pendiente'),
        _PackViewPreset(name: 'Urgentes', statusValue: 'Urgente'),
      ],
    ),
    _PackTemplateSpec(
      id: 'gps_puntos',
      pack: 'Relevamiento/GPS',
      name: 'Puntos GPS',
      description: 'Captura de puntos y estado en terreno.',
      icon: CupertinoIcons.location_solid,
      tags: <String>['GPS', 'Puntos', 'Terreno'],
      workflowReview: true,
      columns: <_PackColumnSpec>[
        _PackColumnSpec(label: 'Fecha', type: 'date', required: true),
        _PackColumnSpec(label: 'Punto ID', type: 'text', required: true),
        _PackColumnSpec(label: 'Latitud', type: 'number', required: true),
        _PackColumnSpec(label: 'Longitud', type: 'number', required: true),
        _PackColumnSpec(
            label: 'Estado',
            type: 'status',
            enumValues: <String>['Pendiente', 'Validado', 'Urgente']),
      ],
      views: <_PackViewPreset>[
        _PackViewPreset(name: 'Campo'),
        _PackViewPreset(name: 'Revision', statusValue: 'Pendiente'),
        _PackViewPreset(name: 'Urgentes', statusValue: 'Urgente'),
      ],
    ),
    _PackTemplateSpec(
      id: 'gps_relevamiento_foto',
      pack: 'Relevamiento/GPS',
      name: 'Relevamiento foto',
      description: 'Registro de ubicación, estado y observación.',
      icon: CupertinoIcons.photo_on_rectangle,
      tags: <String>['Relevamiento', 'Foto', 'Ubicación'],
      columns: <_PackColumnSpec>[
        _PackColumnSpec(label: 'Fecha', type: 'date', required: true),
        _PackColumnSpec(label: 'Ubicación', type: 'text', required: true),
        _PackColumnSpec(label: 'Estado', type: 'status', enumValues: <String>[
          'Pendiente',
          'Revisar',
          'Completado',
          'Urgente'
        ]),
        _PackColumnSpec(label: 'Observacion', type: 'text'),
        _PackColumnSpec(label: 'Referencia', type: 'text'),
      ],
      views: <_PackViewPreset>[
        _PackViewPreset(name: 'Campo'),
        _PackViewPreset(name: 'Revision', statusValue: 'Revisar'),
        _PackViewPreset(name: 'Urgentes', statusValue: 'Urgente'),
      ],
    ),
    _PackTemplateSpec(
      id: 'gps_incidencias_ruta',
      pack: 'Relevamiento/GPS',
      name: 'Incidencias en ruta',
      description: 'Incidencias con progresiva y prioridad.',
      icon: CupertinoIcons.map_pin_ellipse,
      tags: <String>['Ruta', 'Incidencias', 'Prioridad'],
      workflowReview: true,
      columns: <_PackColumnSpec>[
        _PackColumnSpec(label: 'Fecha', type: 'date', required: true),
        _PackColumnSpec(
            label: 'Km/Progresiva',
            type: 'number',
            required: true,
            numberMin: 0),
        _PackColumnSpec(label: 'Estado', type: 'status', enumValues: <String>[
          'Pendiente',
          'En progreso',
          'Resuelto',
          'Urgente'
        ]),
        _PackColumnSpec(
            label: 'Prioridad',
            type: 'status',
            enumValues: <String>['Baja', 'Media', 'Alta', 'Urgente']),
        _PackColumnSpec(label: 'Detalle', type: 'text', required: true),
      ],
      views: <_PackViewPreset>[
        _PackViewPreset(name: 'Campo'),
        _PackViewPreset(name: 'Revision', statusValue: 'Pendiente'),
        _PackViewPreset(name: 'Urgentes', statusValue: 'Urgente'),
      ],
    ),
  ];

  // --------------------- Data ---------------------
  List<SheetMeta> _items = <SheetMeta>[];
  String _q = '';
  bool _searchAll = false;
  _ViewMode _view = _ViewMode.list;
  _SortMode _sort = _SortMode.updatedDesc;
  _HomeTab _tab = _HomeTab.sheets;

  // Dashboard UX
  _QuickFilter _quick = _QuickFilter.none;
  _DailyFocusTab _dailyFocusTab = _DailyFocusTab.recents;
  bool _proSectionExpanded = false;
  bool _proBenefitsExpanded = false;
  bool _demoSectionExpanded = false;

  // Carpeta seleccionada (solo aplica en _HomeTab.sheets)
  String _selectedFolderId = ''; // '' = Raíz

  // --------------------- Preferences (correo destino + engine url) ---------------------
  static const String _kPrefDefaultEmail = 'bitflow.default_email';
  static const String _kPrefAutoSend = 'bitflow.auto_send';

  // Engine URL (FastAPI / Python)
  static const String _kPrefEngineBaseUrlLegacy = 'bitflow.engine_base_url';
  static const int _kDefaultEnginePort = 8001;
  static const String _kPrefOnboardingDone = 'bitflow.onboarding_done.v1';

  bool _prefsLoaded = false;
  String? _prefsLoadError;
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
  static const String _kPrefFavoriteSheets = 'bitflow.favorite_sheets.v1';
  static const String _kPrefSheetLastOpenedAt = 'bitflow.sheet_last_opened.v1';
  static const String _kPrefTrash = 'bitflow.trash.v1';
  static const String _kPrefDemoModeEnabled = 'bitflow.demo_mode_enabled.v1';
  static const String _kPrefDemoSampleSheetId =
      'bitflow.demo_sample_sheet_id.v1';
  static const String _kProCtaUrl = String.fromEnvironment(
    'PRO_CTA_URL',
    defaultValue: '',
  );
  static const String _kProCtaUrlLegacy = String.fromEnvironment(
    'BITFLOW_PRO_CTA_URL',
    defaultValue: '',
  );
  static const String _kSupportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: '',
  );
  static const String _kSupportWhatsApp = String.fromEnvironment(
    'SUPPORT_WHATSAPP',
    defaultValue: '',
  );
  static const String _kSupportUrlLegacy = String.fromEnvironment(
    'BITFLOW_SUPPORT_URL',
    defaultValue: '',
  );
  static const String _kReleaseVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.3.0',
  );

  bool _orgLoaded = false;
  String? _orgLoadError;

  final List<_Folder> _folders = <_Folder>[];
  final Map<String, String> _sheetFolder =
      <String, String>{}; // sheetId -> folderId
  final Map<String, int> _sheetCreatedAtMs = <String, int>{}; // sheetId -> ms
  final Map<String, String> _sheetNotes = <String, String>{}; // sheetId -> note
  final Set<String> _favoriteSheetIds = <String>{};
  final Map<String, int> _sheetLastOpenedAtMs =
      <String, int>{}; // sheetId -> openedAtMs
  final Map<String, int> _trashDeletedAtMs =
      <String, int>{}; // sheetId -> deletedAtMs
  bool _demoModeEnabled = true;
  String _demoSampleSheetId = '';

  // --------------------- Busy state ---------------------
  bool _busy = false;
  String? _busySheetId;
  String _busyMessage = '';
  bool _busyCanCancel = false;
  bool _busyCancelRequested = false;

  // --------------------- Controllers ---------------------
  late final TextEditingController _searchEC;
  final FocusNode _homeKeyFocus = FocusNode(debugLabel: 'StartPageHomeFocus');

  String get _buildStamp => BuildInfo.stamp;
  String get _proCtaUrl {
    final primary = _kProCtaUrl.trim();
    if (primary.isNotEmpty) return primary;
    return _kProCtaUrlLegacy.trim();
  }

  String get _supportEmailOrDefault {
    final env = _kSupportEmail.trim();
    if (env.isNotEmpty) return env;
    return 'soporte@bitflow.app';
  }

  String get _supportWhatsAppDigits {
    final raw = _kSupportWhatsApp.trim();
    if (raw.isEmpty) return '';
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  final AppUpdateService _appUpdateService = const AppUpdateService();
  AppUpdateSnapshot? _updateSnapshot;
  bool _updateChecking = false;
  bool _hideUpdateBanner = false;
  bool _iosInstallHelperHiddenSession = false;
  bool _iosInstallHelperHiddenPersistent = false;
  static const String _kPrefIosInstallHelperDismissed =
      'bitflow.ios_install_helper_dismissed.v1';

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
    unawaited(_loadIosInstallHelperPref());
    unawaited(_checkForUpdates(silent: true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_maybeShowOnboarding());
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _toastEntry?.remove();
    _searchEC.dispose();
    _homeKeyFocus.dispose();
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    var changedDemoMarker = false;
    setState(() {
      _items = SheetStore.list();
      final sampleId = _demoSampleSheetId.trim();
      if (sampleId.isNotEmpty && !_items.any((m) => m.id == sampleId)) {
        _demoSampleSheetId = '';
        changedDemoMarker = true;
      }
    });
    if (_orgLoaded) {
      unawaited(_syncCreatedAtForKnownSheets());
      unawaited(_purgeExpiredTrashIfNeeded());
      if (changedDemoMarker) {
        unawaited(_saveOrg());
      }
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
        _prefsLoaded = true;
        _prefsLoadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _prefsLoaded = true;
        _prefsLoadError = e.toString();
      });
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
      _prefsLoaded = true;
      _prefsLoadError = null;
    });
  }

  Future<void> _maybeShowOnboarding() async {
    try {
      final p = await SharedPreferences.getInstance();
      final done = p.getBool(_kPrefOnboardingDone) ?? false;
      if (done || !mounted) return;
      await _showOnboardingDialog();
    } catch (_) {}
  }

  Future<void> _markOnboardingDone() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kPrefOnboardingDone, true);
    } catch (_) {}
  }

  Future<void> _showOnboardingDialog() async {
    if (!mounted) return;
    final controller = PageController();
    int page = 0;
    bool dontShow = false;

    Future<void> closeDialog(BuildContext ctx) async {
      final navigator = Navigator.of(ctx);
      if (dontShow) {
        await _markOnboardingDone();
      }
      if (!mounted) return;
      navigator.pop();
    }

    Future<void> closeAndRun(
      BuildContext ctx,
      Future<void> Function() action,
    ) async {
      final navigator = Navigator.of(ctx);
      if (dontShow) {
        await _markOnboardingDone();
      }
      if (!mounted) return;
      navigator.pop();
      await action();
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            void goNext() {
              if (page < 2) {
                controller.nextPage(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
              }
            }

            void goBack() {
              if (page > 0) {
                controller.previousPage(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                );
              }
            }

            Widget buildDots() {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: page == i ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: page == i
                          ? Theme.of(ctx).colorScheme.primary
                          : Theme.of(ctx).dividerColor,
                    ),
                  ),
                ),
              );
            }

            return AppModal(
              title: 'Primeros pasos',
              showClose: true,
              maxWidth: 560,
              actions: [
                if (page > 0)
                  AppButton(
                    label: 'Volver',
                    variant: AppButtonVariant.ghost,
                    onPressed: goBack,
                  ),
                AppButton(
                  label: 'Ahora no',
                  variant: AppButtonVariant.ghost,
                  onPressed: () => closeDialog(ctx),
                ),
                AppButton(
                  label: page < 2 ? 'Siguiente' : 'Listo',
                  variant: AppButtonVariant.primary,
                  onPressed: () async {
                    if (page < 2) {
                      goNext();
                      return;
                    }
                    await closeDialog(ctx);
                  },
                ),
              ],
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 220,
                    child: PageView(
                      controller: controller,
                      onPageChanged: (v) => setLocal(() => page = v),
                      children: const [
                        _OnboardingPage(
                          title: '1. Que es BitFlow',
                          body:
                              'BitFlow te permite registrar datos en campo con una hoja simple y evidencias por celda.',
                        ),
                        _OnboardingPage(
                          title: '2. Crea tu primera hoja',
                          body:
                              'Empieza en segundos con una hoja vacía o una plantilla base.',
                        ),
                        _OnboardingPage(
                          title: '3. Importa un paquete',
                          body:
                              'Si ya trabajabas antes, importa un paquete ZIP para continuar donde quedaste.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  buildDots(),
                  const SizedBox(height: 8),
                  if (page == 1)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppButton(
                          label: 'Crear hoja',
                          variant: AppButtonVariant.primary,
                          onPressed: () => closeAndRun(ctx, _newSheet),
                        ),
                        AppButton(
                          label: 'Crear plantilla',
                          variant: AppButtonVariant.secondary,
                          onPressed: () => closeAndRun(ctx, _newTemplateSheet),
                        ),
                      ],
                    ),
                  if (page == 2)
                    AppButton(
                      label: 'Importar paquete ZIP',
                      variant: AppButtonVariant.secondary,
                      onPressed: () => closeAndRun(ctx, _importBackupZip),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Switch.adaptive(
                        value: dontShow,
                        onChanged: (v) => setLocal(() => dontShow = v),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text('No mostrar de nuevo'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool _looksLikeHttpUrl(String s) {
    var v = s.trim();
    if (v.isEmpty) return true; // permitir sin configurar

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
      final favoritesRaw = p.getString(_kPrefFavoriteSheets) ?? '[]';
      final openedRaw = p.getString(_kPrefSheetLastOpenedAt) ?? '{}';
      final trashRaw = p.getString(_kPrefTrash) ?? '{}';
      final demoModeEnabled = p.getBool(_kPrefDemoModeEnabled) ?? true;
      final demoSampleSheetId =
          (p.getString(_kPrefDemoSampleSheetId) ?? '').trim();

      final foldersJson = _safeJsonDecodeList(foldersRaw);
      final folderMapJson = _safeJsonDecodeMap(folderMapRaw);
      final createdJson = _safeJsonDecodeMap(createdRaw);
      final notesJson = _safeJsonDecodeMap(notesRaw);
      final favoritesJson = _safeJsonDecodeList(favoritesRaw);
      final openedJson = _safeJsonDecodeMap(openedRaw);
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

      _favoriteSheetIds
        ..clear()
        ..addAll(
          favoritesJson
              .map((entry) => (entry['id'] ?? '').toString().trim())
              .where((id) => id.isNotEmpty),
        );

      _sheetLastOpenedAtMs
        ..clear()
        ..addAll(_mapStringInt(openedJson));

      _trashDeletedAtMs
        ..clear()
        ..addAll(_mapStringInt(trashJson));
      _demoModeEnabled = demoModeEnabled;
      _demoSampleSheetId = demoSampleSheetId;

      if (!mounted) return;
      setState(() {
        _orgLoaded = true;
        _orgLoadError = null;
      });

      // Primera sincronización: createdAt para planillas existentes + purge TTL.
      await _syncCreatedAtForKnownSheets();
      await _purgeExpiredTrashIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _orgLoaded = true;
        _orgLoadError = e.toString();
      });
    }
  }

  Future<void> _saveOrg() async {
    final p = await SharedPreferences.getInstance();

    final foldersJson = jsonEncode(_folders.map((f) => f.toJson()).toList());
    final folderMapJson = jsonEncode(_sheetFolder);
    final createdJson = jsonEncode(_sheetCreatedAtMs);
    final notesJson = jsonEncode(_sheetNotes);
    final favoritesJson = jsonEncode([
      for (final sheetId in _favoriteSheetIds) <String, dynamic>{'id': sheetId},
    ]);
    final openedJson = jsonEncode(_sheetLastOpenedAtMs);
    final trashJson = jsonEncode(_trashDeletedAtMs);

    await p.setString(_kPrefFolders, foldersJson);
    await p.setString(_kPrefSheetFolder, folderMapJson);
    await p.setString(_kPrefSheetCreatedAt, createdJson);
    await p.setString(_kPrefSheetNotes, notesJson);
    await p.setString(_kPrefFavoriteSheets, favoritesJson);
    await p.setString(_kPrefSheetLastOpenedAt, openedJson);
    await p.setString(_kPrefTrash, trashJson);
    await p.setBool(_kPrefDemoModeEnabled, _demoModeEnabled);
    await p.setString(_kPrefDemoSampleSheetId, _demoSampleSheetId.trim());
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

    final knownIds = _items.map((m) => m.id).toSet();
    final staleFavorites = _favoriteSheetIds.difference(knownIds);
    if (staleFavorites.isNotEmpty) {
      _favoriteSheetIds.removeAll(staleFavorites);
      changed = true;
    }
    final staleOpened = _sheetLastOpenedAtMs.keys
        .where((id) => !knownIds.contains(id))
        .toList(growable: false);
    if (staleOpened.isNotEmpty) {
      for (final id in staleOpened) {
        _sheetLastOpenedAtMs.remove(id);
      }
      changed = true;
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
        _favoriteSheetIds.remove(id);
        _sheetLastOpenedAtMs.remove(id);

        purged++;
      } catch (_) {
        // Se mantiene en papelera para no revivir datos inconsistentes.
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

  TemplateKind? _templateFromChoice(_CreateSheetChoice choice) {
    switch (choice) {
      case _CreateSheetChoice.blank:
        return null;
      case _CreateSheetChoice.plantilla:
        return TemplateKind.plantilla;
      case _CreateSheetChoice.resistividades:
        return TemplateKind.resistividades;
      case _CreateSheetChoice.inventario:
        return TemplateKind.inventario;
      case _CreateSheetChoice.checklist:
        return TemplateKind.checklist;
    }
  }

  Future<_CreateSheetChoice?> _showCreateSheetGallery({
    required bool includeBlank,
  }) async {
    if (!mounted) return null;
    final theme = Theme.of(context);
    final pal = _ApplePalette(
      isLight: theme.brightness == Brightness.light,
      colorScheme: theme.colorScheme,
      scaffold: theme.scaffoldBackgroundColor,
    );
    final border = pal.separator;

    return showModalBottomSheet<_CreateSheetChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) {
        Widget card({
          required _CreateSheetChoice value,
          required IconData icon,
          required String title,
          required String subtitle,
          bool emphasized = false,
        }) {
          return InkWell(
            key: ValueKey('create-sheet-choice-${value.name}'),
            onTap: () => Navigator.of(ctx).pop(value),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: emphasized ? pal.surface : pal.group,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: pal.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: pal.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: pal.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pal.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: pal.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
              boxShadow: [pal.subtleShadow],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      includeBlank ? 'Crear planilla' : 'Elegir plantilla',
                      style: TextStyle(
                        color: pal.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon:
                          Icon(CupertinoIcons.xmark, color: pal.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.2,
                  children: [
                    if (includeBlank)
                      card(
                        value: _CreateSheetChoice.blank,
                        icon: CupertinoIcons.doc_text,
                        title: 'Planilla vacía',
                        subtitle: 'Empieza desde cero con columnas editables.',
                        emphasized: true,
                      ),
                    card(
                      value: _CreateSheetChoice.plantilla,
                      icon: CupertinoIcons.square_grid_2x2,
                      title: 'Plantilla base',
                      subtitle:
                          'Actividad, Detalle, Estado, Responsable, Fecha.',
                    ),
                    card(
                      value: _CreateSheetChoice.resistividades,
                      icon: CupertinoIcons.waveform_path_ecg,
                      title: 'Resistividades',
                      subtitle: 'Fecha, Progresiva, 1m, 3m, 5m, Observaciones.',
                    ),
                    card(
                      value: _CreateSheetChoice.inventario,
                      icon: CupertinoIcons.cube_box,
                      title: 'Inventario',
                      subtitle: 'Item, Cantidad, Unidad, Ubicación, Nota.',
                    ),
                    card(
                      value: _CreateSheetChoice.checklist,
                      icon: CupertinoIcons.checkmark_alt_circle,
                      title: 'Checklist diario',
                      subtitle:
                          'Tarea, Responsable, Estado, Fecha, Comentario.',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showTemplatePackPreview(_PackTemplateSpec template) async {
    if (!mounted) return false;
    final theme = Theme.of(context);
    final pal = _ApplePalette(
      isLight: theme.brightness == Brightness.light,
      colorScheme: theme.colorScheme,
      scaffold: theme.scaffoldBackgroundColor,
    );
    return (await showAppModal<bool>(
          context: context,
          title: template.name,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${template.pack} | ${template.description}',
                style: TextStyle(color: pal.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tag in template.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: pal.separator),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: pal.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Columnas y reglas',
                style: TextStyle(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              for (final col in template.columns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '- ${col.label} (${col.type})'
                    '${col.required ? ' | obligatorio' : ''}'
                    '${col.enumValues.isNotEmpty ? ' | ${col.enumValues.join('/')}' : ''}',
                    style: TextStyle(color: pal.textSecondary, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                'Vistas preconfiguradas',
                style: TextStyle(
                  color: pal.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                template.views.map((e) => e.name).join(' | '),
                style: TextStyle(color: pal.textSecondary, fontSize: 12),
              ),
              if (template.workflowReview) ...[
                const SizedBox(height: 8),
                Text(
                  'Incluye workflow de revision/firmado.',
                  style: TextStyle(color: pal.textSecondary, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            AppButton(
              label: AppStrings.cancel,
              variant: AppButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            AppButton(
              label: 'Crear desde template',
              variant: AppButtonVariant.primary,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
          showClose: false,
          barrierDismissible: true,
        )) ??
        false;
  }

  Future<_PackTemplateSpec?> _showTemplatePackGallery() async {
    if (!mounted) return null;
    final theme = Theme.of(context);
    final pal = _ApplePalette(
      isLight: theme.brightness == Brightness.light,
      colorScheme: theme.colorScheme,
      scaffold: theme.scaffoldBackgroundColor,
    );
    return showModalBottomSheet<_PackTemplateSpec>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final border = pal.separator;
        final grouped = <String, List<_PackTemplateSpec>>{};
        for (final template in _commercialTemplates) {
          grouped.putIfAbsent(template.pack, () => <_PackTemplateSpec>[]).add(
                template,
              );
        }

        Widget card(_PackTemplateSpec template) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final navigator = Navigator.of(ctx);
                final create = await _showTemplatePackPreview(template);
                if (!mounted || !create) return;
                navigator.pop(template);
              },
              child: Ink(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                  boxShadow: [pal.subtleShadow],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: pal.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Icon(
                        template.icon,
                        size: 17,
                        color: pal.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      template.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        template.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: pal.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: template.tags
                          .map(
                            (tag) => Text(
                              '#$tag',
                              style: TextStyle(
                                color: pal.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: pal.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: border),
              boxShadow: [pal.subtleShadow],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Template Packs',
                        style: TextStyle(
                          color: pal.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: Icon(CupertinoIcons.xmark,
                            color: pal.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Selecciona un template premium y revisa preview antes de crear.',
                    style: TextStyle(color: pal.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  for (final entry in grouped.entries) ...[
                    Text(
                      entry.key,
                      style: TextStyle(
                        color: pal.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.2,
                      children: [
                        for (final template in entry.value) card(template),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool _openEditorRouteInFlight = false;

  Future<void> _openEditorRoute({
    required String sheetId,
    String? initialName,
  }) async {
    if (!mounted || _openEditorRouteInFlight) return;
    _openEditorRouteInFlight = true;
    try {
      _markSheetOpened(sheetId);
      final encodedSheetId = Uri.encodeComponent(sheetId.trim());
      final cleanName = (initialName ?? '').trim();
      final route = cleanName.isEmpty
          ? '/app/sheet/$encodedSheetId'
          : '/app/sheet/$encodedSheetId?name=${Uri.encodeQueryComponent(cleanName)}';

      var openedWithRouter = false;
      try {
        await context.push(route);
        openedWithRouter = true;
      } catch (_) {
        openedWithRouter = false;
      }

      if (!openedWithRouter) {
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          CupertinoPageRoute(
            builder: (_) => EditorScreen(
              isLight: widget.isLight,
              onToggleTheme: widget.onToggleTheme,
              sheetId: sheetId,
              initialName: cleanName.isEmpty ? null : cleanName,
              engineBaseUrl: _engineBaseForEditor(),
            ),
          ),
        );
      }

      if (!mounted) return;
      _reload();
    } finally {
      _openEditorRouteInFlight = false;
    }
  }

  void _markSheetOpened(String sheetId) {
    final trimmed = sheetId.trim();
    if (trimmed.isEmpty) return;
    _sheetLastOpenedAtMs[trimmed] = DateTime.now().millisecondsSinceEpoch;
    unawaited(_saveOrg());
  }

  Future<void> _createAndOpenSheet({TemplateKind? template}) async {
    if (_busy) return;

    final id = template == null
        ? SheetStore.createNew()
        : SheetStore.createFromTemplate(template);

    _sheetCreatedAtMs[id] = DateTime.now().millisecondsSinceEpoch;
    if (_tab == _HomeTab.sheets && _selectedFolderId.isNotEmpty) {
      _sheetFolder[id] = _selectedFolderId;
    }

    await _saveOrg();
    _reload();
    if (!mounted) return;

    await _openEditorRoute(sheetId: id);
  }

  String _packColId(String label, int index) {
    final normalized = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    if (normalized.isEmpty) return 'col_${index + 1}';
    return 'col_$normalized';
  }

  Map<String, dynamic> _buildPackModel(_PackTemplateSpec template) {
    final headers = <String>[for (final col in template.columns) col.label];
    final colIds = <String>[
      for (int i = 0; i < template.columns.length; i++)
        _packColId(template.columns[i].label, i),
    ];
    final columnPrefs = <String, dynamic>{};
    final rowDefaults = <String>[
      for (final col in template.columns) col.defaultValue?.trim() ?? '',
    ];

    for (int i = 0; i < template.columns.length; i++) {
      final col = template.columns[i];
      final colId = colIds[i];
      final pref = <String, dynamic>{
        'type': col.type,
      };
      if (col.required) pref['required'] = true;
      if (col.enumValues.isNotEmpty) pref['enumValues'] = col.enumValues;
      if (col.numberMin != null) pref['numberMin'] = col.numberMin;
      if (col.numberMax != null) pref['numberMax'] = col.numberMax;
      columnPrefs[colId] = pref;
    }

    return <String, dynamic>{
      'name': template.name,
      'savedAt': DateTime.now().toIso8601String(),
      'headers': headers,
      'colIds': colIds,
      'rows': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'r_1',
          'cells': rowDefaults,
        },
      ],
      'columnPrefs': columnPrefs,
      'columnOrder': colIds,
      'templateKind': template.id,
      'templatePack': template.pack,
      if (template.workflowReview) 'workflowPreset': 'review',
    };
  }

  Future<void> _seedTemplateSavedViews({
    required String sheetId,
    required _PackTemplateSpec template,
    required List<String> colIds,
    required List<String> headers,
  }) async {
    if (template.views.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'bitflow:sheet:$sheetId:$_kPrefSavedViews';
      int? statusIndex;
      int? textIndex;
      int? dateIndex;
      for (int i = 0; i < headers.length; i++) {
        final h = headers[i].toLowerCase();
        if (statusIndex == null &&
            (h.contains('estado') || h.contains('status'))) {
          statusIndex = i;
        }
        if (textIndex == null &&
            (h.contains('detalle') ||
                h.contains('hallazgo') ||
                h.contains('observ'))) {
          textIndex = i;
        }
        if (dateIndex == null && h.contains('fecha')) {
          dateIndex = i;
        }
      }
      final now = DateTime.now();
      final payload = <Map<String, dynamic>>[];
      for (int i = 0; i < template.views.length; i++) {
        final view = template.views[i];
        payload.add(<String, dynamic>{
          'id': 'view_${template.id}_${i + 1}',
          'name': view.name,
          'createdAt': now.subtract(Duration(minutes: i)).toIso8601String(),
          if (statusIndex != null &&
              (view.statusValue?.trim().isNotEmpty ?? false))
            'statusColId': colIds[statusIndex],
          if (view.statusValue?.trim().isNotEmpty ?? false)
            'statusValue': view.statusValue,
          if (textIndex != null &&
              (view.textContains?.trim().isNotEmpty ?? false))
            'textColId': colIds[textIndex],
          if (view.textContains?.trim().isNotEmpty ?? false)
            'textContains': view.textContains,
          if (dateIndex != null) 'dateColId': colIds[dateIndex],
        });
      }
      await prefs.setString(key, jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> _createAndOpenPackTemplate(_PackTemplateSpec template) async {
    if (_busy) return;
    final model = _buildPackModel(template);
    final id = SheetStore.createFromModel(model);
    _sheetCreatedAtMs[id] = DateTime.now().millisecondsSinceEpoch;
    if (_tab == _HomeTab.sheets && _selectedFolderId.isNotEmpty) {
      _sheetFolder[id] = _selectedFolderId;
    }
    await _saveOrg();
    await _seedTemplateSavedViews(
      sheetId: id,
      template: template,
      colIds: (model['colIds'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      headers: (model['headers'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
    );
    _reload();
    if (!mounted) return;
    await _openEditorRoute(sheetId: id);
  }

  Future<void> _newSheet() async {
    if (_busy) return;
    final choice = await _showCreateSheetGallery(includeBlank: true);
    if (!mounted || choice == null) return;
    final template = _templateFromChoice(choice);
    await _createAndOpenSheet(template: template);
  }

  Future<void> _newTemplateSheet() async {
    if (_busy) return;
    final template = await _showTemplatePackGallery();
    if (!mounted || template == null) return;
    await _createAndOpenPackTemplate(template);
  }

  Future<void> _openDiagnostics() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => DiagnosticsScreen(),
      ),
    );
  }

  Future<void> _openStaticPage(Widget page) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => page,
      ),
    );
  }

  Future<void> _openLicenses() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LicensePage(
          applicationName: 'BitFlow',
          applicationVersion: BuildInfo.stamp,
        ),
      ),
    );
  }

  Future<void> _createSmokeTestSheet() async {
    if (_busy) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final headers = <String>[
      'Actividad',
      'GPS',
      'Foto',
      'Audio',
      'Notas',
    ];
    final rows = <List<String>>[
      <String>[
        'Relevamiento inicial',
        '',
        '',
        '',
        'Registrar ubicación del punto inspeccionado.',
      ],
      <String>[
        'Evidencia fotográfica',
        '',
        '',
        '',
        'Adjuntar foto del estado actual.',
      ],
      <String>[
        'Observación de cierre',
        '',
        '',
        '',
        'Grabar audio breve con hallazgos y próximos pasos.',
      ],
    ];

    final state = TableState(
      headers: headers,
      rows: rows,
      savedAt: DateTime.now(),
    );

    SheetStore.saveState(id, state);
    SheetStore.rename(id, 'Demo inspección en campo');

    _sheetCreatedAtMs[id] = DateTime.now().millisecondsSinceEpoch;
    if (_tab == _HomeTab.sheets && _selectedFolderId.isNotEmpty) {
      _sheetFolder[id] = _selectedFolderId;
    }
    await _saveOrg();

    _reload();
    if (!mounted) return;

    await _openEditorRoute(sheetId: id);
  }

  bool get _demoSampleLoaded {
    final id = _demoSampleSheetId.trim();
    if (id.isEmpty) return false;
    if (_trashDeletedAtMs.containsKey(id)) return false;
    return _items.any((m) => m.id == id);
  }

  Future<void> _loadDemoSampleSheet() async {
    if (_busy) return;

    final existingId = _demoSampleSheetId.trim();
    if (existingId.isNotEmpty &&
        _items.any((m) => m.id == existingId) &&
        !_trashDeletedAtMs.containsKey(existingId)) {
      await _openEditorRoute(sheetId: existingId);
      return;
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final headers = <String>[
      'Fecha',
      'Actividad',
      'Estado',
      'Responsable',
      'Observacion',
      'Fotos',
    ];
    final rows = <List<String>>[
      <String>[
        DateTime.now().toIso8601String().substring(0, 10),
        'Relevamiento inicial',
        'OK',
        'Operador A',
        'Inicio de jornada validado',
        '',
      ],
      <String>[
        DateTime.now().toIso8601String().substring(0, 10),
        'Punto GPS',
        'Pendiente',
        'Operador B',
        'Capturar coordenadas y foto de evidencia',
        '',
      ],
      <String>[
        DateTime.now().toIso8601String().substring(0, 10),
        'Cierre de turno',
        'Pendiente',
        'Supervisor',
        'Registrar observaciones finales',
        '',
      ],
    ];

    final state = TableState(
      headers: headers,
      rows: rows,
      savedAt: DateTime.now(),
    );

    SheetStore.saveState(id, state);
    SheetStore.rename(id, 'Ejemplo BitFlow (demo)');
    _sheetCreatedAtMs[id] = DateTime.now().millisecondsSinceEpoch;
    _sheetNotes[id] =
        'Ejemplo reversible de demostracion. Puedes quitarlo desde Inicio.';
    _trashDeletedAtMs.remove(id);
    _demoSampleSheetId = id;
    await _saveOrg();
    _reload();
    if (!mounted) return;
    _toast('Ejemplo demo cargado. Puedes quitarlo cuando quieras.');
    await _openEditorRoute(sheetId: id);
  }

  Future<void> _removeDemoSample({bool notify = true}) async {
    final id = _demoSampleSheetId.trim();
    if (id.isEmpty) {
      if (notify) _toast('No hay ejemplo demo activo.');
      return;
    }

    try {
      SheetStore.delete(id);
      _trashDeletedAtMs.remove(id);
      _sheetNotes.remove(id);
      _sheetFolder.remove(id);
      _sheetCreatedAtMs.remove(id);
      _favoriteSheetIds.remove(id);
      _sheetLastOpenedAtMs.remove(id);
      _demoSampleSheetId = '';
      await _saveOrg();
      _reload();
      if (notify && mounted) {
        _toast('Ejemplo demo eliminado.');
      }
    } catch (e) {
      if (!mounted) return;
      _toast('No se pudo quitar el ejemplo demo: $e');
    }
  }

  Future<void> _toggleDemoMode() async {
    if (_busy) return;
    final next = !_demoModeEnabled;
    setState(() => _demoModeEnabled = next);
    if (!next && _demoSampleLoaded) {
      await _removeDemoSample(notify: false);
    } else {
      await _saveOrg();
      _reload();
    }
    if (!mounted) return;
    _toast(
      next
          ? 'Modo demo activado. Puedes cargar un ejemplo temporal.'
          : 'Modo demo desactivado.',
    );
  }

  String _genAttachmentId(String prefix) {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = DateTime.now().millisecondsSinceEpoch % 100000;
    return '$prefix$now$rand';
  }

  String _audioStoredRefFrom(StoredAudio stored) {
    final key = stored.storageKey.trim();
    if (key.isEmpty) return '';
    if (key.startsWith('file:') ||
        key.startsWith('key:') ||
        key.startsWith('mem:')) {
      return key;
    }
    final hasSlash = key.contains('\\') || key.contains('/');
    if (key.contains(':') && !hasSlash) return 'key:$key';
    return hasSlash ? 'file:$key' : 'key:$key';
  }

  Uint8List _archiveFileBytes(ArchiveFile file) {
    return file.content;
  }

  CellRef? _resolveImportCellRef(
    String rawKey, {
    required String newSheetId,
    required List<String> rowIds,
    required List<String> colIds,
  }) {
    final ref = CellRef.fromKey(rawKey, defaultSheetId: newSheetId);
    if (ref != null) return ref.withSheet(newSheetId);
    final cell = CellKey.fromKey(rawKey);
    if (cell == null) return null;
    if (cell.row < 0 || cell.row >= rowIds.length) return null;
    if (cell.col < 0 || cell.col >= colIds.length) return null;
    return CellRef(
      sheetId: newSheetId,
      rowId: rowIds[cell.row],
      colId: colIds[cell.col],
    );
  }

  void _setStartPageState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  void _beginBusyOperation({
    required String message,
    required bool canCancel,
    String? busySheetId,
  }) {
    if (!mounted) {
      _busy = true;
      _busySheetId = busySheetId;
      _busyMessage = message;
      _busyCanCancel = canCancel;
      _busyCancelRequested = false;
      return;
    }
    _setStartPageState(() {
      _busy = true;
      _busySheetId = busySheetId;
      _busyMessage = message;
      _busyCanCancel = canCancel;
      _busyCancelRequested = false;
    });
  }

  void _setBusyMessage(String message) {
    if (_busyMessage == message) return;
    if (!mounted) {
      _busyMessage = message;
      return;
    }
    _setStartPageState(() => _busyMessage = message);
  }

  void _requestBusyCancel() {
    if (!_busyCanCancel || _busyCancelRequested) return;
    if (!mounted) {
      _busyCancelRequested = true;
      _busyMessage = AppStrings.progressCancelling;
    } else {
      _setStartPageState(() {
        _busyCancelRequested = true;
        _busyMessage = AppStrings.progressCancelling;
      });
    }
    _toast(AppStrings.infoOperationCancelling);
  }

  void _throwIfBusyCancelled() {
    if (_busyCancelRequested) {
      throw const _StartPageOperationCancelled();
    }
  }

  void _endBusyOperation() {
    if (!mounted) {
      _busy = false;
      _busySheetId = null;
      _busyMessage = '';
      _busyCanCancel = false;
      _busyCancelRequested = false;
      return;
    }
    _setStartPageState(() {
      _busy = false;
      _busySheetId = null;
      _busyMessage = '';
      _busyCanCancel = false;
      _busyCancelRequested = false;
    });
  }

  bool _importBackupZipInFlight = false;

  Future<void> _importBackupZip() async {
    if (_busy || _importBackupZipInFlight) {
      _toast('Ya hay una operacion en curso. Espera a que termine.');
      return;
    }
    _importBackupZipInFlight = true;
    final typeGroup = const XTypeGroup(
      label: 'Backup ZIP',
      extensions: ['zip'],
    );

    XFile? file;
    try {
      try {
        file = await openFile(acceptedTypeGroups: [typeGroup]);
      } catch (e, st) {
        final outcome = classifyExportFlowOutcome(e);
        if (outcome == ExportFlowOutcome.cancelled) {
          _toast(AppStrings.infoImportCancelled);
          return;
        }
        if (outcome == ExportFlowOutcome.unsupported) {
          _reportStartPageErrorMessage(
            'start_page_import_zip_unsupported_platform',
            flow: AppErrorFlow.importData,
            operation: 'import_backup_open_picker',
            fallbackMessage:
                'La importacion ZIP desde Inicio no esta disponible en este dispositivo.',
          );
          return;
        }
        _reportStartPageError(
          e,
          flow: AppErrorFlow.importData,
          operation: 'import_backup_open_picker',
          stackTrace: st,
          fallbackMessage:
              'No pudimos abrir el selector de archivos para importar.',
        );
        return;
      }
    } finally {
      if (!mounted) {
        _importBackupZipInFlight = false;
      } else {
        _setStartPageState(() => _importBackupZipInFlight = false);
      }
    }
    if (!mounted) return;
    if (file == null || _busy) return;

    _beginBusyOperation(
      message: AppStrings.progressImportingBackup,
      canCancel: true,
      busySheetId: null,
    );

    try {
      _throwIfBusyCancelled();
      final bytes = await file.readAsBytes();
      _throwIfBusyCancelled();
      if (bytes.isEmpty) {
        _reportStartPageErrorMessage(
          'import_empty_file',
          flow: AppErrorFlow.importData,
          operation: 'import_backup_read_bytes',
          fallbackMessage: 'Archivo vacio.',
        );
        return;
      }

      final archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? backupFile;
      ArchiveFile? sheetFile;
      ArchiveFile? manifestFile;
      for (final f in archive) {
        final name = f.name.trim();
        if (name == 'backup.json' || name.endsWith('/backup.json')) {
          backupFile = f;
        } else if (name == 'sheet.json' || name.endsWith('/sheet.json')) {
          sheetFile = f;
        } else if (name == 'manifest.json' || name.endsWith('/manifest.json')) {
          manifestFile = f;
        }
      }
      if (backupFile == null && sheetFile == null) {
        _reportStartPageErrorMessage(
          'package_json_missing',
          flow: AppErrorFlow.importData,
          operation: 'import_backup_lookup_manifest',
          fallbackMessage:
              'No se encontro backup.json ni sheet.json en el ZIP.',
        );
        return;
      }

      late final Map<String, dynamic> sheetRaw;
      List<dynamic> assetsRaw = const <dynamic>[];
      if (backupFile != null) {
        final backupRaw =
            jsonDecode(utf8.decode(_archiveFileBytes(backupFile)));
        if (backupRaw is! Map) {
          _reportStartPageErrorMessage(
            'backup_invalid_root',
            flow: AppErrorFlow.importData,
            operation: 'import_backup_decode_json',
            fallbackMessage: 'Backup invalido.',
          );
          return;
        }
        final sheetCandidate = backupRaw['sheet'];
        if (sheetCandidate is! Map) {
          _reportStartPageErrorMessage(
            'backup_invalid_missing_sheet',
            flow: AppErrorFlow.importData,
            operation: 'import_backup_validate_sheet',
            fallbackMessage: 'Backup invalido: falta sheet.',
          );
          return;
        }
        sheetRaw = Map<String, dynamic>.from(sheetCandidate);
        assetsRaw = (backupRaw['assets'] as List?) ?? const <dynamic>[];
      } else {
        final sheetCandidate =
            jsonDecode(utf8.decode(_archiveFileBytes(sheetFile!)));
        if (sheetCandidate is! Map) {
          _reportStartPageErrorMessage(
            'package_invalid_sheet_json',
            flow: AppErrorFlow.importData,
            operation: 'import_package_decode_sheet_json',
            fallbackMessage: 'sheet.json invalido.',
          );
          return;
        }
        sheetRaw = Map<String, dynamic>.from(sheetCandidate);
        if (manifestFile != null) {
          final manifestRaw =
              jsonDecode(utf8.decode(_archiveFileBytes(manifestFile)));
          if (manifestRaw is Map) {
            assetsRaw = (manifestRaw['assets'] as List?) ?? const <dynamic>[];
            if (assetsRaw.isEmpty) {
              final cellsRaw = manifestRaw['cells'];
              if (cellsRaw is Map) {
                final flattened = <Map<String, dynamic>>[];
                for (final entry in cellsRaw.entries) {
                  if (entry.value is! Map) continue;
                  final cellMap = Map<String, dynamic>.from(entry.value as Map);
                  final photos = cellMap['photos'];
                  if (photos is List) {
                    for (final item in photos) {
                      if (item is! Map) continue;
                      final next = Map<String, dynamic>.from(item);
                      next.putIfAbsent('kind', () => 'photo');
                      next.putIfAbsent('cellKey', () => entry.key.toString());
                      flattened.add(next);
                    }
                  }
                  final audios = cellMap['audios'];
                  if (audios is List) {
                    for (final item in audios) {
                      if (item is! Map) continue;
                      final next = Map<String, dynamic>.from(item);
                      next.putIfAbsent('kind', () => 'audio');
                      next.putIfAbsent('cellKey', () => entry.key.toString());
                      flattened.add(next);
                    }
                  }
                }
                assetsRaw = flattened;
              }
            }
          }
        }
      }

      final normalized = SheetStore.normalizeModel(sheetRaw);
      final rowsRaw = (normalized['rows'] as List?) ?? const [];
      final rowIds = <String>[];
      for (final r in rowsRaw) {
        if (r is Map) {
          rowIds.add((r['id'] ?? '').toString());
        }
      }
      final colIds = (normalized['colIds'] as List?)
              ?.map((e) => (e ?? '').toString())
              .toList() ??
          const <String>[];

      final newSheetId = DateTime.now().millisecondsSinceEpoch.toString();
      normalized['savedAt'] = DateTime.now().toIso8601String();

      final assetsById = <String, Map<String, dynamic>>{};
      for (final a in assetsRaw) {
        _throwIfBusyCancelled();
        if (a is! Map) continue;
        final kind = (a['kind'] ?? '').toString();
        final id = (a['id'] ?? '').toString();
        if (kind.isEmpty || id.isEmpty) continue;
        assetsById['$kind:$id'] = a.cast<String, dynamic>();
      }

      final filesByPath = <String, ArchiveFile>{};
      for (final f in archive) {
        filesByPath[f.name] = f;
      }

      int importedPhotos = 0;
      int importedAudios = 0;
      int missingAssets = 0;
      _setBusyMessage(AppStrings.progressImportingAssets);

      final cellMetaRaw = normalized['cellMeta'];
      final nextCellMeta = <String, dynamic>{};
      if (cellMetaRaw is Map) {
        for (final entry in cellMetaRaw.entries) {
          _throwIfBusyCancelled();
          final rawKey = entry.key.toString();
          final metaRaw = entry.value;
          if (metaRaw is! Map) continue;

          final ref = _resolveImportCellRef(
            rawKey,
            newSheetId: newSheetId,
            rowIds: rowIds,
            colIds: colIds,
          );
          if (ref == null) continue;

          final nextMeta = <String, dynamic>{};
          final gps = metaRaw['gps'];
          if (gps is Map && gps.isNotEmpty) nextMeta['gps'] = gps;

          final photosRaw = metaRaw['photos'];
          if (photosRaw is List) {
            final updatedPhotos = <Map<String, dynamic>>[];
            for (final p in photosRaw) {
              _throwIfBusyCancelled();
              if (p is! Map) continue;
              final idRaw = (p['id'] ?? '').toString();
              final id = idRaw.isNotEmpty ? idRaw : _genAttachmentId('ph_');
              final asset =
                  assetsById['photo:$idRaw'] ?? assetsById['photo:$id'];
              final assetPath = (asset?['path'] ?? '').toString();
              final fileName =
                  (p['name'] ?? asset?['fileName'] ?? 'foto.jpg').toString();
              final mime =
                  (p['mime'] ?? asset?['mime'] ?? 'image/jpeg').toString();
              final thumbRef = (p['thumbRef'] ?? '').toString();

              Uint8List? contentBytes;
              if (assetPath.isNotEmpty && filesByPath.containsKey(assetPath)) {
                contentBytes = _archiveFileBytes(filesByPath[assetPath]!);
              } else {
                if (assetPath.isNotEmpty) missingAssets++;
              }

              var storedRef = (p['storedRef'] ?? '').toString();
              var size = (p['size'] as num?)?.toInt() ?? 0;

              if (contentBytes != null && contentBytes.isNotEmpty) {
                final save = await AttachmentStore.I.saveImage(
                  cellRef: ref,
                  attachmentId: id,
                  bytes: contentBytes,
                  originalName: fileName,
                  mime: mime,
                  webFile: null,
                );
                if (save != null && save.storedRef.trim().isNotEmpty) {
                  storedRef = save.storedRef;
                  size = contentBytes.lengthInBytes;
                  importedPhotos++;
                }
              } else {
                storedRef = '';
                size = 0;
              }

              final updated = <String, dynamic>{
                'id': id,
                'name': fileName,
                'mime': mime,
                'size': size,
                'storedRef': storedRef,
                'thumbRef': thumbRef,
                'addedAt': (p['addedAt'] ?? DateTime.now().toIso8601String())
                    .toString(),
                'lastKnown': (p['lastKnown'] as bool?) ?? false,
              };
              final caption = (p['caption'] ?? '').toString().trim();
              if (caption.isNotEmpty) updated['caption'] = caption;
              if (p['lat'] != null) updated['lat'] = p['lat'];
              if (p['lon'] != null) updated['lon'] = p['lon'];
              if (p['acc'] != null) updated['acc'] = p['acc'];

              updatedPhotos.add(updated);
            }
            if (updatedPhotos.isNotEmpty) nextMeta['photos'] = updatedPhotos;
          }

          final audiosRaw = metaRaw['audios'];
          if (audiosRaw is List) {
            final updatedAudios = <Map<String, dynamic>>[];
            for (final a in audiosRaw) {
              _throwIfBusyCancelled();
              if (a is! Map) continue;
              final idRaw = (a['id'] ?? '').toString();
              final id = idRaw.isNotEmpty ? idRaw : _genAttachmentId('au_');
              final asset =
                  assetsById['audio:$idRaw'] ?? assetsById['audio:$id'];
              final assetPath = (asset?['path'] ?? '').toString();
              final fileName =
                  (a['name'] ?? asset?['fileName'] ?? 'audio.m4a').toString();
              final mime =
                  (a['mime'] ?? asset?['mime'] ?? 'audio/m4a').toString();
              final durationMs = (a['durationMs'] as num?)?.toInt() ??
                  (asset?['durationMs'] as num?)?.toInt() ??
                  0;

              Uint8List? contentBytes;
              if (assetPath.isNotEmpty && filesByPath.containsKey(assetPath)) {
                contentBytes = _archiveFileBytes(filesByPath[assetPath]!);
              } else {
                if (assetPath.isNotEmpty) missingAssets++;
              }

              var storedRef = (a['storedRef'] ?? '').toString();
              var size = (a['size'] as num?)?.toInt() ?? 0;

              if (contentBytes != null && contentBytes.isNotEmpty) {
                final recording = RecordedAudio(
                  fileName: fileName,
                  mime: mime,
                  duration: Duration(milliseconds: durationMs),
                  bytes: contentBytes,
                );
                final stored = await AudioStorageService.I.saveRecording(
                  sheetId: newSheetId,
                  cellKey: ref.compactKey,
                  attachmentId: id,
                  recording: recording,
                );
                if (stored != null) {
                  storedRef = _audioStoredRefFrom(stored);
                  size = stored.bytesLength;
                  importedAudios++;
                }
              } else {
                storedRef = '';
                size = 0;
              }

              final updated = <String, dynamic>{
                'id': id,
                'name': fileName,
                'mime': mime,
                'size': size,
                'durationMs': durationMs,
                'storedRef': storedRef,
                'addedAt': (a['addedAt'] ?? DateTime.now().toIso8601String())
                    .toString(),
              };
              updatedAudios.add(updated);
            }
            if (updatedAudios.isNotEmpty) nextMeta['audios'] = updatedAudios;
          }

          if (nextMeta.isNotEmpty) {
            nextCellMeta[ref.key] = nextMeta;
          }
        }
      }

      if (nextCellMeta.isNotEmpty) {
        normalized['cellMeta'] = nextCellMeta;
      } else {
        normalized.remove('cellMeta');
      }

      _setBusyMessage(AppStrings.progressWritingFile);
      _throwIfBusyCancelled();
      SheetStore.saveModel(newSheetId, normalized);

      _sheetCreatedAtMs[newSheetId] = DateTime.now().millisecondsSinceEpoch;
      if (_tab == _HomeTab.sheets && _selectedFolderId.isNotEmpty) {
        _sheetFolder[newSheetId] = _selectedFolderId;
      }
      await _saveOrg();

      _reload();

      final summary =
          'Backup importado. Fotos: $importedPhotos, Audios: $importedAudios';
      if (missingAssets > 0) {
        _toast('$summary. Faltantes: $missingAssets');
      } else {
        _toast(summary);
      }
    } on _StartPageOperationCancelled {
      _toast(AppStrings.infoImportCancelled);
    } catch (e, st) {
      final outcome = classifyExportFlowOutcome(e);
      if (outcome == ExportFlowOutcome.cancelled) {
        _toast(AppStrings.infoImportCancelled);
        return;
      }
      if (outcome == ExportFlowOutcome.unsupported) {
        _reportStartPageErrorMessage(
          'start_page_import_zip_unsupported_platform',
          flow: AppErrorFlow.importData,
          operation: 'import_backup_zip',
          fallbackMessage:
              'La importacion ZIP desde Inicio no esta disponible en este dispositivo.',
        );
        return;
      }
      _reportStartPageError(
        e,
        flow: AppErrorFlow.importData,
        operation: 'import_backup_zip',
        stackTrace: st,
      );
    } finally {
      _endBusyOperation();
    }
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

    await _openEditorRoute(
      sheetId: m.id,
      initialName: m.title,
    );
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

  Future<void> _toggleFavorite(SheetMeta m) async {
    if (_busy) return;
    final isFavorite = _favoriteSheetIds.contains(m.id);
    if (isFavorite) {
      _favoriteSheetIds.remove(m.id);
    } else {
      _favoriteSheetIds.add(m.id);
    }
    await _saveOrg();
    if (!mounted) return;
    setState(() {});
    _toast(isFavorite ? 'Quitada de favoritas.' : 'Marcada como favorita.');
  }

  String _buildDuplicateName(String baseName) {
    final source = baseName.trim().isEmpty ? 'Planilla' : baseName.trim();
    return '$source (copia)';
  }

  Future<void> _duplicateSheet(SheetMeta m) async {
    if (_busy) return;
    final raw = SheetStore.loadRaw(m.id);
    if (raw == null || raw.trim().isEmpty) {
      _toast('No se pudo duplicar: planilla sin datos.');
      return;
    }

    String newId = '';
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final model = decoded.cast<String, dynamic>();
        model['name'] = _buildDuplicateName(m.title);
        model['savedAt'] = DateTime.now().toIso8601String();
        newId = SheetStore.createFromModel(model);
      } else {
        final table = SheetStore.load(m.id);
        if (table == null) {
          _toast('No se pudo duplicar esta planilla.');
          return;
        }
        newId = SheetStore.createNew();
        SheetStore.saveState(
          newId,
          TableState(
            headers: table.headers,
            rows: table.rows,
            savedAt: DateTime.now(),
          ),
        );
        SheetStore.rename(newId, _buildDuplicateName(m.title));
      }
    } catch (_) {
      final table = SheetStore.load(m.id);
      if (table == null) {
        _toast('No se pudo duplicar esta planilla.');
        return;
      }
      newId = SheetStore.createNew();
      SheetStore.saveState(
        newId,
        TableState(
          headers: table.headers,
          rows: table.rows,
          savedAt: DateTime.now(),
        ),
      );
      SheetStore.rename(newId, _buildDuplicateName(m.title));
    }

    if (newId.isEmpty) {
      _toast('No se pudo duplicar esta planilla.');
      return;
    }

    final folderId = _sheetFolder[m.id] ?? '';
    if (folderId.isNotEmpty) {
      _sheetFolder[newId] = folderId;
    }
    _sheetCreatedAtMs[newId] = DateTime.now().millisecondsSinceEpoch;
    _sheetLastOpenedAtMs[newId] = DateTime.now().millisecondsSinceEpoch;
    await _saveOrg();
    _reload();
    if (!mounted) return;
    _toast('Planilla duplicada.');
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
    _favoriteSheetIds.remove(m.id);
    _sheetLastOpenedAtMs.remove(m.id);
    await _saveOrg();

    _reload();
    _toast('Eliminada definitivamente.');
  }

  Future<void> _exportSheet(SheetMeta m) async {
    if (_busy) return;

    final raw = SheetStore.loadRaw(m.id);
    if (raw == null) {
      _reportStartPageErrorMessage(
        'sheet_raw_not_found',
        flow: AppErrorFlow.exportData,
        operation: 'export_sheet_load_raw',
        fallbackMessage: 'No se pudo leer la planilla.',
      );
      return;
    }

    _beginBusyOperation(
      message: AppStrings.progressExportingSheet,
      canCancel: true,
      busySheetId: m.id,
    );

    try {
      _throwIfBusyCancelled();
      final parsed = await JsonWorker.parseOnce(raw);
      _throwIfBusyCancelled();
      final name = _sanitizeFileName(m.title.isEmpty ? 'bitflow' : m.title);
      _setBusyMessage(AppStrings.progressWritingFile);

      await ExportXlsxService.download(
        fileName: name, // sin .xlsx
        headers: parsed.headers,
        rows: parsed.rows,
      );
      _throwIfBusyCancelled();

      if (!mounted) return;
      _toast('Exportado como $name.xlsx');

      // Estado de producto (sin fragilidad): avisamos configuración.
      if (_autoSend && _defaultEmail.isNotEmpty) {
        _toast('Auto-envío activo: destino ${_defaultEmail.trim()}');
      }
    } on _StartPageOperationCancelled {
      _toast(AppStrings.infoExportCancelled);
    } catch (e, st) {
      final outcome = classifyExportFlowOutcome(e);
      if (outcome == ExportFlowOutcome.cancelled) {
        _toast(AppStrings.infoExportCancelled);
        return;
      }
      if (outcome == ExportFlowOutcome.unsupported) {
        _reportStartPageErrorMessage(
          'start_page_export_xlsx_unsupported_platform',
          flow: AppErrorFlow.exportData,
          operation: 'export_sheet_xlsx',
          fallbackMessage:
              'La exportación XLSX desde Inicio no está disponible en este dispositivo. Abrí la planilla y exportá ZIP/PDF desde el editor.',
        );
        return;
      }
      if (!mounted) return;
      _reportStartPageError(
        e,
        flow: AppErrorFlow.exportData,
        operation: 'export_sheet_xlsx',
        fallbackMessage:
            'No pudimos exportar la planilla. Intentá nuevamente o usá exportación desde el editor.',
        stackTrace: st,
      );
    } finally {
      _endBusyOperation();
    }
  }

  // --------------------- Notes (mensaje destacado) ---------------------

  Future<void> _editNote(SheetMeta m) async {
    final current = (_sheetNotes[m.id] ?? '').trim();

    final result = await _promptMultilineCupertino(
      title: 'Mensaje destacado',
      initialValue: current,
      placeholder: 'Ej: Enviar a cliente hoy 18:00 / WP: revisar medición 3',
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
              child: const Text('Nueva carpeta'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _openFolderManagerPage();
              },
              child: const Text('Gestionar carpetas'),
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
        builder: (routeCtx) => _FolderManagerPage(
          isLight: widget.isLight,
          folders: _folders,
          getCount: _countSheetsInFolder,
          onCreate: () => _createFolderDialog(routeCtx),
          onRename: (f) => _renameFolderDialog(routeCtx, f),
          onDelete: (f) => _deleteFolderFlow(routeCtx, f),
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
      message: 'Las planillas vuelven a Raíz. Eliminar ${folder.name}?',
      okText: 'Eliminar',
      danger: true,
    );
    if (!mounted || !ctx.mounted) return;
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
            'Ejemplos: $suggested, Septiembre 2026, Obra X. Un solo nivel, simple y ordenado.',
      ),
    );
    if (!mounted || !ctx.mounted) return null;

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
    if (!mounted || !ctx.mounted) return null;

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
            final theme = Theme.of(ctx);
            final pal = _ApplePalette(
              isLight: theme.brightness == Brightness.light,
              colorScheme: theme.colorScheme,
              scaffold: theme.scaffoldBackgroundColor,
            );
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
                          ? 'Modo Automático usa el tunel HTTPS. Si cambia el tunel, pasa a Manual y pega la nueva URL.'
                          : 'Modo Automático intenta LAN y cae al tunel. En movil fisico usa IP LAN o tunel en Manual.',
                      isLight: pal.isLight,
                    ),
                    const SizedBox(height: 10),
                    CupertinoSlidingSegmentedControl<String>(
                      groupValue: engineMode,
                      children: const <String, Widget>{
                        EngineConfig.modeAuto: Text('Automático'),
                        EngineConfig.modeManual: Text('Manual'),
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
                            color: pal.colorScheme.error,
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
                          color: pal.textSecondary,
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
                        color: pal.group,
                        borderRadius: BorderRadius.circular(10),
                        child: Text(
                          testing ? 'Probando...' : 'Probar conexión',
                          style: TextStyle(
                            color: pal.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CupertinoInfoBanner(
                      icon: CupertinoIcons.paperplane,
                      title: 'Correo destino',
                      message:
                          'Registrá un correo destino. Tu flujo de export (Editor/Backend/Service) puede usarlo para enviar planillas sin pasos extra.',
                      isLight: pal.isLight,
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
                            color: pal.colorScheme.error,
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
            message: 'URL manual vacía.',
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
      return 'Error HTTP del motor ${error.statusCode}: ${error.bodySnippet}';
    }
    final text = error.toString();
    if (kIsWeb &&
        (text.contains('XMLHttpRequest') || text.contains('Failed to fetch'))) {
      return 'CORS bloqueado: habilitar allow_origins en FastAPI para el dominio del tunel.';
    }
    return 'No se pudo conectar al engine. $text';
  }

  Future<void> _checkForUpdates({bool silent = false}) async {
    if (_updateChecking) return;
    if (mounted) {
      setState(() => _updateChecking = true);
    } else {
      _updateChecking = true;
    }

    final result = await _appUpdateService.checkForUpdates();
    if (!mounted) return;

    setState(() {
      _updateChecking = false;
      _updateSnapshot = result;
      if (result.updateAvailable) {
        _hideUpdateBanner = false;
      }
    });

    if (!silent) {
      _toast(result.message);
    }
  }

  bool get _shouldShowIosInstallHelper {
    if (!kIsWeb) return false;
    if (_iosInstallHelperHiddenSession || _iosInstallHelperHiddenPersistent) {
      return false;
    }
    if (!WebCapabilities.isIosSafari) return false;
    if (WebCapabilities.isStandalone) return false;
    if (WebCapabilities.isInAppBrowser) return false;
    return true;
  }

  Future<void> _loadIosInstallHelperPref() async {
    if (!kIsWeb) return;
    if (!WebCapabilities.isIosSafari) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_kPrefIosInstallHelperDismissed) ?? false;
      if (!mounted) {
        _iosInstallHelperHiddenPersistent = dismissed;
        return;
      }
      setState(() => _iosInstallHelperHiddenPersistent = dismissed);
    } catch (_) {}
  }

  Future<void> _dismissIosInstallHelperForever() async {
    if (!mounted) return;
    setState(() {
      _iosInstallHelperHiddenSession = true;
      _iosInstallHelperHiddenPersistent = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefIosInstallHelperDismissed, true);
    } catch (_) {}
  }

  Future<void> _applyAvailableUpdate() async {
    final current = _updateSnapshot;
    if (current == null || !current.updateAvailable) {
      _toast('No hay actualizaciones pendientes.');
      return;
    }

    if (kIsWeb) {
      final result = await ForceUpdateService.I.forceUpdate();
      if (!mounted) return;
      _toast(result.message.trim().isEmpty
          ? 'Recargando version nueva...'
          : result.message);
      return;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final url = Uri.parse(AppUpdateService.androidLatestApkUrl);
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!mounted) return;
      _toast(opened
          ? 'Abriendo descarga de Android...'
          : 'No se pudo abrir la descarga.');
      return;
    }

    final releaseUrl = Uri.parse(
      'https://github.com/marcoluna-nqn/bitacora_web/releases/latest',
    );
    final opened =
        await launchUrl(releaseUrl, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    _toast(opened
        ? 'Abriendo pagina de release.'
        : 'En iOS: usa Safari y actualiza desde la web/PWA.');
  }

  _StartNotice? _buildPriorityNotice() {
    if (_tab != _HomeTab.sheets) return null;

    final update = _updateSnapshot;
    if (!_hideUpdateBanner && update != null && update.updateAvailable) {
      final remote = update.remoteVersion.trim();
      return _StartNotice(
        message: remote.isEmpty
            ? 'Actualizacion disponible para BitFlow.'
            : 'Actualizacion $remote disponible.',
        actionLabel: kIsWeb ? 'Recargar' : 'Descargar',
        detailsTitle: 'Actualizacion disponible',
        detailsBody: remote.isEmpty
            ? 'Hay una version nueva lista para instalar.'
            : 'Version detectada: $remote.\nInstala para recibir mejoras y correcciones.',
        onAction: _applyAvailableUpdate,
      );
    }

    if (kIsWeb && WebCapabilities.isInAppBrowser) {
      return _StartNotice(
        message: 'Navegador embebido: permisos y guardado pueden fallar.',
        actionLabel: 'Abrir navegador',
        detailsTitle: 'Abrir en Safari o Chrome',
        detailsBody:
            'Los navegadores embebidos bloquean camara, microfono, GPS y guardado local. Abre BitFlow en Safari o Chrome para operar sin friccion.',
        onAction: _openInExternalBrowser,
      );
    }

    if (_shouldShowIosInstallHelper) {
      return _StartNotice(
        message: 'Instala BitFlow en Safari para acceso rapido.',
        actionLabel: 'Entendido',
        detailsTitle: 'Instalar en iPhone',
        detailsBody:
            'Desde Safari: Compartir -> Anadir a pantalla de inicio. Asi se abre como app y evita pasos extra.',
        onAction: _dismissIosInstallHelperForever,
      );
    }

    if (RuntimeFlags.demoMode && _demoModeEnabled) {
      return _StartNotice(
        message: 'Modo demo activo para pruebas reversibles.',
        actionLabel: 'Cerrar',
        detailsTitle: 'Modo demo',
        detailsBody:
            'La demo muestra valor rapido sin tocar datos reales. Puedes activarla de nuevo cuando quieras.',
        onAction: _toggleDemoMode,
      );
    }

    return null;
  }

  Future<void> _openInExternalBrowser() async {
    if (!kIsWeb) return;
    final opened =
        await launchUrl(Uri.base, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!opened) {
      _toast('No se pudo abrir en navegador externo.');
    }
  }

  Future<void> _showNoticeDetails(_StartNotice notice) async {
    if (!mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (ctx) {
        return CupertinoAlertDialog(
          title: Text(notice.detailsTitle),
          content: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(notice.detailsBody),
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openSupportChannel() async {
    final supportUrl = _kSupportUrlLegacy.trim();
    if (supportUrl.isNotEmpty) {
      final uri = Uri.tryParse(supportUrl);
      if (uri != null) {
        final opened =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (opened) return;
      }
    }

    final supportWhatsAppDigits = _supportWhatsAppDigits;
    if (supportWhatsAppDigits.isNotEmpty) {
      final wa = Uri.parse(
        'https://wa.me/$supportWhatsAppDigits?text=${Uri.encodeComponent('Hola, necesito soporte de BitFlow.')}',
      );
      final opened = await launchUrl(wa, mode: LaunchMode.externalApplication);
      if (opened) return;
    }

    final mail = Uri(
      scheme: 'mailto',
      path: _supportEmailOrDefault,
      queryParameters: <String, String>{
        'subject': 'Soporte cliente BitFlow',
      },
    );

    final sent = await launchUrl(mail, mode: LaunchMode.externalApplication);
    if (sent) return;

    final issues = Uri.parse(
      'https://github.com/marcoluna-nqn/bitacora_web/issues',
    );
    final opened =
        await launchUrl(issues, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _toast('No se pudo abrir soporte. Escribenos a $_supportEmailOrDefault.');
    }
  }

  Future<void> _openMoreSheet(_ApplePalette colors) async {
    final items = <_MoreSheetItem>[
      _MoreSheetItem(
        icon: CupertinoIcons.headphones,
        title: 'Soporte',
        subtitle: 'Abrir WhatsApp, email o canal de ayuda',
        onSelected: _openSupportChannel,
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.info_circle,
        title: 'Acerca de BitFlow',
        subtitle: 'Version, build y estado de la app',
        onSelected: () => _openStaticPage(const AboutScreen()),
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.waveform_path_ecg,
        title: 'Diagnostico',
        subtitle: 'Verifica motor, adjuntos y conectividad',
        onSelected: _openDiagnostics,
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.arrow_down_doc,
        title: 'Importar paquete ZIP',
        subtitle: 'Restaurar planillas desde respaldo',
        onSelected: _importBackupZip,
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.arrow_up_doc,
        title: 'Nueva plantilla',
        subtitle: 'Crear desde una plantilla comercial',
        onSelected: _newTemplateSheet,
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.bolt,
        title: 'Prueba rapida',
        subtitle: 'Validar GPS, fotos y audio en una hoja ejemplo',
        onSelected: _createSmokeTestSheet,
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.settings,
        title: 'Ajustes',
        subtitle: 'Correo, motor y preferencias de trabajo',
        onSelected: _openMailSettings,
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.folder,
        title: 'Carpetas',
        subtitle: 'Organiza planillas por areas o clientes',
        onSelected: _openFolderPicker,
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.search_circle,
        title: 'Quick Switcher',
        subtitle: 'Cambiar rapido con Ctrl/Cmd+K',
        onSelected: _openQuickSwitcher,
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.refresh,
        title: 'Buscar actualizaciones',
        subtitle: (_updateSnapshot?.updateAvailable ?? false)
            ? 'Hay una actualizacion lista para instalar'
            : (_updateChecking
                ? 'Buscando actualizaciones en este momento'
                : 'Comprobar nuevas versiones ahora'),
        onSelected: () => _checkForUpdates(silent: false),
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.cart,
        title: 'Premium',
        subtitle: 'Planes, alcance y activacion comercial',
        onSelected: _openCommercialInfo,
      ),
      if (RuntimeFlags.demoMode)
        _MoreSheetItem(
          icon:
              _demoModeEnabled ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
          title: _demoModeEnabled ? 'Desactivar demo' : 'Activar demo',
          subtitle: 'Controla la demo reversible para presentaciones',
          onSelected: _toggleDemoMode,
        ),
      _MoreSheetItem(
        icon: CupertinoIcons.doc_text_search,
        title: 'Agente de planillas',
        subtitle: 'MVP asistido para crear planillas',
        onSelected: () => _openStaticPage(const SpreadsheetAgentScreen()),
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.sort_down,
        title: 'Ordenar',
        subtitle: 'Recientes, titulo o cantidad de filas',
        onSelected: _openSortSheet,
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.square_grid_2x2,
        title: 'Vista',
        subtitle: 'Alterna entre lista y grilla',
        onSelected: _openViewSheet,
      ),
      _MoreSheetItem(
        icon: _tab == _HomeTab.sheets
            ? CupertinoIcons.trash
            : CupertinoIcons.doc_plaintext,
        title: _tab == _HomeTab.sheets ? 'Ir a Papelera' : 'Ir a Planillas',
        subtitle: 'Cambiar entre contenido activo y eliminado',
        onSelected: () async {
          if (!mounted) return;
          setState(() {
            _tab = _tab == _HomeTab.sheets ? _HomeTab.trash : _HomeTab.sheets;
            _quick = _QuickFilter.none;
          });
        },
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.lock_shield,
        title: 'Privacidad',
        subtitle: 'Politica de uso y tratamiento de datos',
        onSelected: () => _openStaticPage(const PrivacyScreen()),
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.doc_text,
        title: 'Terminos',
        subtitle: 'Condiciones y responsabilidades de uso',
        onSelected: () => _openStaticPage(const TermsScreen()),
      ),
      _MoreSheetItem(
        icon: CupertinoIcons.book,
        title: 'Licencias',
        subtitle: 'Creditos de librerias de terceros',
        onSelected: _openLicenses,
      ),
      if (RuntimeFlags.isAuthRequired)
        _MoreSheetItem(
          icon: CupertinoIcons.escape,
          title: 'Cerrar sesion',
          subtitle: 'Salir del usuario actual',
          onSelected: _signOutCurrentUser,
          destructive: true,
        ),
    ];

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).padding.bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + bottomInset),
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.separator),
                boxShadow: [colors.subtleShadow],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.separator,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Mas',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 0),
                          borderRadius: BorderRadius.circular(999),
                          color: colors.group,
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text(
                            'Cerrar',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Container(
                        height: 1,
                        color: colors.separator,
                      ),
                      itemBuilder: (_, index) {
                        final item = items[index];
                        return _MoreSheetRow(
                          colors: colors,
                          item: item,
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await item.onSelected();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCommercialInfo() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const PremiumScreen(),
      ),
    );
  }

  Future<Uri?> _buildCommercialContactUri() async {
    final cfg = await AppConfig.load();
    const fallbackWhatsapp = '+54 9 299 620 9136';
    const fallbackEmail = 'marcoantoniolunavillegas@gmail.com';

    final whatsappText = cfg.whatsappMessage.trim().isNotEmpty
        ? cfg.whatsappMessage.trim()
        : 'Hola, quiero informacion sobre BitFlow Pro.';
    final supportEnvDigits = _supportWhatsAppDigits;
    if (supportEnvDigits.isNotEmpty) {
      return Uri.parse(
        'https://wa.me/$supportEnvDigits?text=${Uri.encodeComponent(whatsappText)}',
      );
    }

    final whatsappRaw = cfg.contactWhatsApp.trim().isNotEmpty
        ? cfg.contactWhatsApp.trim()
        : fallbackWhatsapp;
    final whatsappDigits = whatsappRaw.replaceAll(RegExp(r'[^0-9]'), '');

    if (whatsappDigits.isNotEmpty) {
      return Uri.parse(
        'https://wa.me/$whatsappDigits?text=${Uri.encodeComponent(whatsappText)}',
      );
    }

    final email = _kSupportEmail.trim().isNotEmpty
        ? _kSupportEmail.trim()
        : (cfg.contactEmail.trim().isNotEmpty
            ? cfg.contactEmail.trim()
            : fallbackEmail);
    if (email.isNotEmpty) {
      return Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: <String, String>{
          'subject': 'Consulta BitFlow Pro',
          'body': 'Hola, quiero conocer precios y alcance de BitFlow Pro.',
        },
      );
    }

    return null;
  }

  Future<void> _openCommercialCta() async {
    final forcedUrl = _proCtaUrl;
    if (forcedUrl.isNotEmpty) {
      final forcedUri = Uri.tryParse(forcedUrl);
      if (forcedUri != null) {
        final opened =
            await launchUrl(forcedUri, mode: LaunchMode.externalApplication);
        if (opened) return;
      }
    }

    final uri = await _buildCommercialContactUri();
    if (uri == null) {
      await _openCommercialInfo();
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _toast('No se pudo abrir el canal de contacto.');
    }
  }

  Future<void> _signOutCurrentUser() async {
    if (!RuntimeFlags.isAuthRequired) {
      _toast('Modo demo activo: no hay sesión para cerrar.');
      return;
    }
    try {
      await AuthService.I.signOut();
    } catch (e) {
      _toast('No se pudo cerrar sesión: $e');
    }
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
              child: const Text('Título (A-Z)'),
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

  void _reportStartPageError(
    Object error, {
    required AppErrorFlow flow,
    required String operation,
    StackTrace? stackTrace,
    String? fallbackMessage,
  }) {
    final appError = AppErrorMapper.from(
      error,
      flow: flow,
      fallbackMessage: fallbackMessage,
    );
    AppErrorReporter.I.record(
      appError,
      operation: operation,
      stackTrace: stackTrace,
    );
    debugPrint('[StartPage] ${appError.toLogLine(operation: operation)}');
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
    _toast(appError.userMessage);
  }

  void _reportStartPageErrorMessage(
    String message, {
    required AppErrorFlow flow,
    required String operation,
    String? fallbackMessage,
  }) {
    final appError = AppErrorMapper.fromMessage(
      message,
      flow: flow,
      fallbackMessage: fallbackMessage,
    );
    AppErrorReporter.I.record(
      appError,
      operation: operation,
    );
    debugPrint('[StartPage] ${appError.toLogLine(operation: operation)}');
    _toast(appError.userMessage);
  }

  @visibleForTesting
  void debugShowBusyOverlay({
    String message = AppStrings.progressPreparingExport,
    bool canCancel = true,
  }) {
    assert(() {
      _beginBusyOperation(
        message: message,
        canCancel: canCancel,
        busySheetId: null,
      );
      return true;
    }());
  }

  @visibleForTesting
  void debugClearBusyOverlay() {
    assert(() {
      _endBusyOperation();
      return true;
    }());
  }

  @visibleForTesting
  bool debugBusyCancelRequested() {
    var cancelled = false;
    assert(() {
      cancelled = _busyCancelRequested;
      return true;
    }());
    return cancelled;
  }

  void _toast(String msg) {
    if (!mounted) return;

    _toastTimer?.cancel();
    _toastEntry?.remove();

    final overlay = Overlay.of(context);

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

  List<SheetMeta> get _activeSheets {
    final list = _items
        .where((m) => !_trashDeletedAtMs.containsKey(m.id))
        .toList(growable: false);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<SheetMeta> get _recentSheets {
    final activeById = <String, SheetMeta>{
      for (final m in _activeSheets) m.id: m,
    };
    final entries = _sheetLastOpenedAtMs.entries
        .where((entry) => activeById.containsKey(entry.key))
        .toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));
    final recents = <SheetMeta>[
      for (final entry in entries) activeById[entry.key]!,
    ];
    if (recents.isNotEmpty) return recents;
    return _activeSheets;
  }

  List<SheetMeta> get _favoriteSheets {
    final active = _activeSheets
        .where((m) => _favoriteSheetIds.contains(m.id))
        .toList(growable: false);
    active.sort((a, b) {
      final openedA = _sheetLastOpenedAtMs[a.id] ?? 0;
      final openedB = _sheetLastOpenedAtMs[b.id] ?? 0;
      if (openedA != openedB) return openedB.compareTo(openedA);
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return active;
  }

  bool _isFavoriteSheet(String sheetId) => _favoriteSheetIds.contains(sheetId);

  List<_PackTemplateSpec> _templateMatchesForQuery(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty) return const <_PackTemplateSpec>[];
    return _commercialTemplates.where((template) {
      final name = template.name.toLowerCase();
      final desc = template.description.toLowerCase();
      final pack = template.pack.toLowerCase();
      final tags = template.tags.join(' ').toLowerCase();
      return name.contains(q) ||
          desc.contains(q) ||
          pack.contains(q) ||
          tags.contains(q);
    }).toList(growable: false);
  }

  bool _isTextInputFocused() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    return focus.context?.widget is EditableText;
  }

  KeyEventResult _onHomeKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_isTextInputFocused()) return KeyEventResult.ignored;
    final isMod = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (isMod && event.logicalKey == LogicalKeyboardKey.keyK) {
      unawaited(_openQuickSwitcher());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _openQuickSwitcher() async {
    if (!mounted) return;
    final actions = <CommandAction>[
      CommandAction(
        id: 'quick_new_sheet',
        label: 'Nueva planilla',
        subtitle: 'Crear planilla vacia',
        icon: CupertinoIcons.plus_rectangle_fill_on_rectangle_fill,
        onSelected: () => unawaited(_newSheet()),
      ),
      CommandAction(
        id: 'quick_from_template',
        label: 'Desde plantilla',
        subtitle: 'Abrir galeria de templates',
        icon: CupertinoIcons.square_grid_2x2_fill,
        onSelected: () => unawaited(_newTemplateSheet()),
      ),
    ];

    for (final sheet in _activeSheets) {
      final title =
          sheet.title.trim().isEmpty ? 'Planilla sin titulo' : sheet.title;
      final suffix = _isFavoriteSheet(sheet.id) ? ' · Favorita' : '';
      actions.add(
        CommandAction(
          id: 'quick_sheet_${sheet.id}',
          label: title,
          subtitle: 'Planilla$suffix · ${_fmt(sheet.updatedAt)}',
          icon: _isFavoriteSheet(sheet.id)
              ? CupertinoIcons.star_fill
              : CupertinoIcons.doc_text,
          onSelected: () => unawaited(_open(sheet)),
        ),
      );
    }

    for (final template in _commercialTemplates) {
      actions.add(
        CommandAction(
          id: 'quick_template_${template.id}',
          label: template.name,
          subtitle: 'Template · ${template.pack}',
          icon: template.icon,
          onSelected: () => unawaited(_createAndOpenPackTemplate(template)),
        ),
      );
    }

    await showCommandPalette(
      context,
      title: 'Quick Switcher',
      actions: actions,
    );
  }

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
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        today++;
      }
      totalRows += m.rows;
    }
    return (total: total, today: today, totalRows: totalRows);
  }

  // --------------------- Build ---------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _ApplePalette(
      isLight: theme.brightness == Brightness.light,
      colorScheme: theme.colorScheme,
      scaffold: theme.scaffoldBackgroundColor,
    );
    final isLight = colors.isLight;
    final startupErrors = <String>[
      if ((_prefsLoadError ?? '').trim().isNotEmpty)
        'Preferencias: ${_prefsLoadError!.trim()}',
      if ((_orgLoadError ?? '').trim().isNotEmpty)
        'Organizacion: ${_orgLoadError!.trim()}',
    ];
    final showInitialLoading = !_prefsLoaded || !_orgLoaded;

    final data = _visibleSheets;
    final recentSheets = _recentSheets.take(6).toList(growable: false);
    final favoriteSheets = _favoriteSheets.take(6).toList(growable: false);
    final templateMatches = _templateMatchesForQuery(_q);
    final sAll = _statsAll;

    final todayCount = sAll.today;
    final scheduledCount =
        0; // placeholder intencional (sin feature de agenda por ahora)
    final allCount = sAll.total;
    final flaggedCount = _countFlaggedSheets();
    final completedCount = _countTrash();

    final mq = MediaQuery.of(context);
    final bottomPad = mq.padding.bottom;
    final keyboardVisible = mq.viewInsets.bottom > 0;
    final route = ModalRoute.of(context);
    final modalRouteActive = route != null && !route.isCurrent;
    final hideFloatingActions = keyboardVisible || modalRouteActive;
    final showDebugBadge = kDebugMode || _kShowDebugBadge;
    final buildStamp = _buildStamp;
    final notice = _buildPriorityNotice();

    return Focus(
      focusNode: _homeKeyFocus,
      autofocus: true,
      onKeyEvent: _onHomeKeyEvent,
      child: CupertinoPageScaffold(
        backgroundColor: colors.bg,
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: _AppleSectionCard(
                        colors: colors,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _tab == _HomeTab.trash
                                            ? 'Papelera'
                                            : 'BitFlow',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.7,
                                          height: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _tab == _HomeTab.trash
                                            ? 'Elementos eliminados recientemente.'
                                            : 'Planillas rapidas para campo y oficina.',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                CupertinoButton(
                                  key: const ValueKey('start-theme-toggle'),
                                  padding: const EdgeInsets.all(8),
                                  minimumSize: const Size(36, 36),
                                  borderRadius: BorderRadius.circular(999),
                                  color: colors.group,
                                  onPressed: widget.onToggleTheme,
                                  child: Icon(
                                    isLight
                                        ? CupertinoIcons.moon_stars
                                        : CupertinoIcons.sun_max,
                                    size: 18,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CupertinoButton(
                                  key: const ValueKey('start-more-button'),
                                  padding: const EdgeInsets.all(8),
                                  minimumSize: const Size(36, 36),
                                  borderRadius: BorderRadius.circular(999),
                                  color: colors.group,
                                  onPressed: () => _openMoreSheet(colors),
                                  child: Icon(
                                    CupertinoIcons.ellipsis,
                                    size: 18,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            if (_tab == _HomeTab.sheets) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  AppButton(
                                    key: const ValueKey('start-primary-new'),
                                    label: 'Nueva planilla',
                                    icon: CupertinoIcons.add_circled_solid,
                                    variant: AppButtonVariant.primary,
                                    onPressed: _busy ? null : _newSheet,
                                  ),
                                  AppButton(
                                    key: const ValueKey('start-primary-search'),
                                    label: 'Buscar',
                                    icon: CupertinoIcons.search,
                                    variant: AppButtonVariant.secondary,
                                    onPressed: _openQuickSwitcher,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Ctrl/Cmd+K para cambiar rapido',
                                key: const ValueKey('start-quick-hint'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (showInitialLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: LoadingState(
                          message: 'Preparando BitFlow para tu primer uso...',
                        ),
                      ),
                    ),
                  if (startupErrors.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: AppErrorState(
                          compact: true,
                          title: 'Algunas preferencias no se cargaron',
                          message:
                              'BitFlow continuo con configuracion segura para evitar bloquear el inicio.',
                          details: startupErrors.join('\n'),
                          actionLabel: 'Reintentar inicio',
                          onAction: () {
                            setState(() {
                              _prefsLoaded = false;
                              _orgLoaded = false;
                              _prefsLoadError = null;
                              _orgLoadError = null;
                            });
                            unawaited(_loadPrefs());
                            unawaited(_loadOrg());
                          },
                        ),
                      ),
                    ),
                  if (_tab == _HomeTab.sheets)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _DashboardQuickSections(
                          colors: colors,
                          recents: recentSheets,
                          favorites: favoriteSheets,
                          fmt: _fmt,
                          selectedTab: _dailyFocusTab,
                          onTabChanged: (_DailyFocusTab tab) {
                            setState(() => _dailyFocusTab = tab);
                          },
                          openedAtBySheetId: _sheetLastOpenedAtMs,
                          isFavorite: _isFavoriteSheet,
                          onOpen: _open,
                          onRename: _rename,
                          onDuplicate: _duplicateSheet,
                          onDelete: _moveToTrash,
                          onToggleFavorite: _toggleFavorite,
                        ),
                      ),
                    ),
                  if (_tab == _HomeTab.sheets)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _ProLicenseCard(
                          colors: colors,
                          busy: _busy,
                          releaseVersion: _kReleaseVersion,
                          demoModeEnabled: _demoModeEnabled,
                          demoSampleLoaded: _demoSampleLoaded,
                          proExpanded: _proSectionExpanded,
                          proBenefitsExpanded: _proBenefitsExpanded,
                          demoExpanded: _demoSectionExpanded,
                          showDemoSection: RuntimeFlags.demoMode,
                          onToggleProExpanded: () {
                            setState(() =>
                                _proSectionExpanded = !_proSectionExpanded);
                          },
                          onToggleBenefits: () {
                            setState(() =>
                                _proBenefitsExpanded = !_proBenefitsExpanded);
                          },
                          onToggleDemoExpanded: () {
                            setState(() =>
                                _demoSectionExpanded = !_demoSectionExpanded);
                          },
                          onPrimaryCta: _openCommercialCta,
                          onLoadDemo: _loadDemoSampleSheet,
                          onRemoveDemo: _removeDemoSample,
                          onToggleDemoMode: _toggleDemoMode,
                        ),
                      ),
                    ),
                  if (notice != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _NoticeArea(
                          colors: colors,
                          notice: notice,
                          onDetails: () => _showNoticeDetails(notice),
                        ),
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

                  // Search + quick switcher
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
                                  'Buscar planillas y plantillas (Ctrl/Cmd+K)',
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Quick Switcher: Ctrl/Cmd+K',
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  minimumSize: const Size(0, 30),
                                  color: colors.group,
                                  borderRadius: BorderRadius.circular(999),
                                  onPressed: _openQuickSwitcher,
                                  child: Text(
                                    'Abrir',
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
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
                            if (_q.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _TemplateSearchResults(
                                colors: colors,
                                templates: templateMatches
                                    .take(3)
                                    .toList(growable: false),
                                onOpenTemplate: (template) => unawaited(
                                    _createAndOpenPackTemplate(template)),
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
                                        : 'Mostrando ${data.length} en ${_folderName(_selectedFolderId)}'),
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
                          onTemplate: _newTemplateSheet,
                          onImport: _importBackupZip,
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
                                      note: (_sheetNotes[data[i].id] ?? '')
                                          .trim(),
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
                                      onMoveToTrash: () =>
                                          _moveToTrash(data[i]),
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

              if (showDebugBadge)
                Positioned(
                  left: 16,
                  bottom: 14 + bottomPad,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
              if (_busy && _busyMessage.trim().isNotEmpty)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.textPrimary.withValues(alpha: 0.16),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: LoadingState(
                          message: _busyMessage,
                          onCancel: (_busyCanCancel && !_busyCancelRequested)
                              ? _requestBusyCancel
                              : null,
                          cancelLabel: AppStrings.cancel,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_tab == _HomeTab.sheets && !hideFloatingActions)
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
        iconBg: colors.accent,
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
          iconBg: colors.accent.withValues(alpha: colors.isLight ? 0.82 : 0.74),
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
        iconBg: colors.accent.withValues(alpha: colors.isLight ? 0.68 : 0.62),
        count: trashCount,
        folderId: '',
        trailingBadge: trashCount > 0 ? '*' : null,
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
      if (v is String) out[k] = v;
      if (v is num) out[k] = v.toString();
    });
    return out;
  }

  Map<String, int> _mapStringInt(Map<String, dynamic> m) {
    final out = <String, int>{};
    m.forEach((k, v) {
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
    final t = AppTheme.of(context);
    final c = t.colors;
    final Color neutralTop =
        c.surfaceElevated.withValues(alpha: c.isLight ? 0.98 : 0.82);
    final Color neutralBottom =
        c.surfaceMuted.withValues(alpha: c.isLight ? 0.96 : 0.72);
    final Color accentTop =
        c.accentMuted.withValues(alpha: c.isLight ? 0.18 : 0.34);
    final Color accentBottom =
        c.surfaceElevated.withValues(alpha: c.isLight ? 0.94 : 0.78);
    final Color warmTop =
        c.surfaceMuted.withValues(alpha: c.isLight ? 0.94 : 0.70);
    final Color warmBottom =
        c.surface.withValues(alpha: c.isLight ? 0.96 : 0.76);

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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accentTop, accentBottom],
                    ),
                    foreground: c.textPrimary,
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
                      colors: [neutralTop, neutralBottom],
                    ),
                    foreground: c.textPrimary,
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
                      colors: [warmTop, warmBottom],
                    ),
                    foreground: c.textPrimary,
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [neutralTop, accentBottom],
                    ),
                    foreground: c.textPrimary,
                    onTap: onTapScheduled,
                  ),
                  SizedBox(height: gap),
                  _SummaryCard(
                    height: cardH,
                    title: 'Con indicador',
                    count: flagged,
                    icon: CupertinoIcons.flag,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [warmTop, accentBottom],
                    ),
                    foreground: c.textPrimary,
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
    required this.foreground,
    required this.onTap,
  });

  final double height;
  final String title;
  final int count;
  final IconData icon;
  final Gradient gradient;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTheme.of(context);
    final iconBg = foreground.withValues(alpha: t.colors.isLight ? 0.14 : 0.24);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      pressedOpacity: 0.7,
      onPressed: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(t.radii.lg),
          border: Border.all(
              color:
                  foreground.withValues(alpha: t.colors.isLight ? 0.22 : 0.26),
              width: 0.8),
          boxShadow: [
            BoxShadow(
              color: t.material.colorScheme.shadow
                  .withValues(alpha: t.colors.isLight ? 0.12 : 0.34),
              blurRadius: 16,
              offset: const Offset(0, 10),
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
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: foreground.withValues(
                          alpha: t.colors.isLight ? 0.24 : 0.28),
                      width: 1),
                ),
                child: Icon(icon, size: 18, color: foreground),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Text(
                '$count',
                style: TextStyle(
                  color: foreground,
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
                style: TextStyle(
                  color: foreground,
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
    final bg = colors.surface;
    final border =
        colors.separator.withValues(alpha: colors.isLight ? 0.35 : 0.22);
    final iconBg =
        colors.accent.withValues(alpha: colors.isLight ? 0.18 : 0.28);
    final iconColor = colors.accent;
    final addBg = colors.group;

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
              color: iconBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(CupertinoIcons.sparkles, color: iconColor, size: 18),
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
            pressedOpacity: 0.55,
            onPressed: onAdd,
            minimumSize: const Size(0, 0),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: addBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: border),
              ),
              child: Icon(CupertinoIcons.add, color: colors.accent, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardQuickSections extends StatelessWidget {
  const _DashboardQuickSections({
    required this.colors,
    required this.recents,
    required this.favorites,
    required this.fmt,
    required this.selectedTab,
    required this.onTabChanged,
    required this.openedAtBySheetId,
    required this.isFavorite,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final _ApplePalette colors;
  final List<SheetMeta> recents;
  final List<SheetMeta> favorites;
  final String Function(DateTime) fmt;
  final _DailyFocusTab selectedTab;
  final ValueChanged<_DailyFocusTab> onTabChanged;
  final Map<String, int> openedAtBySheetId;
  final bool Function(String sheetId) isFavorite;
  final ValueChanged<SheetMeta> onOpen;
  final ValueChanged<SheetMeta> onRename;
  final ValueChanged<SheetMeta> onDuplicate;
  final ValueChanged<SheetMeta> onDelete;
  final ValueChanged<SheetMeta> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final activeTab = selectedTab;
    final visibleItems =
        (activeTab == _DailyFocusTab.recents ? recents : favorites)
            .take(3)
            .toList(growable: false);
    final emptyMessage = activeTab == _DailyFocusTab.recents
        ? 'Todavia no abriste planillas. Crea una para empezar.'
        : 'Marca planillas como favoritas para verlas aqui.';

    return _AppleSectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recientes y favoritas',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Abre lo que usas todos los dias.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DailyTabChip(
                label: 'Recientes',
                selected: activeTab == _DailyFocusTab.recents,
                colors: colors,
                onTap: () => onTabChanged(_DailyFocusTab.recents),
              ),
              _DailyTabChip(
                label: 'Favoritas',
                selected: activeTab == _DailyFocusTab.favorites,
                colors: colors,
                onTap: () => onTabChanged(_DailyFocusTab.favorites),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (visibleItems.isEmpty)
            Text(
              emptyMessage,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            )
          else
            Column(
              children: [
                for (int i = 0; i < visibleItems.length; i++) ...[
                  _DashboardQuickRow(
                    colors: colors,
                    meta: visibleItems[i],
                    subtitle: _openedAtLabel(visibleItems[i].id),
                    favorite: isFavorite(visibleItems[i].id),
                    onOpen: () => onOpen(visibleItems[i]),
                    onRename: () => onRename(visibleItems[i]),
                    onDuplicate: () => onDuplicate(visibleItems[i]),
                    onDelete: () => onDelete(visibleItems[i]),
                    onToggleFavorite: () => onToggleFavorite(visibleItems[i]),
                  ),
                  if (i < visibleItems.length - 1)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      height: 1,
                      color: colors.separator.withValues(
                        alpha: colors.isLight ? 0.8 : 0.4,
                      ),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  String _openedAtLabel(String sheetId) {
    final openedAtMs = openedAtBySheetId[sheetId];
    if (openedAtMs == null) return 'Abierta recientemente';
    return 'Abierta ${fmt(DateTime.fromMillisecondsSinceEpoch(openedAtMs))}';
  }
}

class _DailyTabChip extends StatelessWidget {
  const _DailyTabChip({
    required this.label,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final _ApplePalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      minimumSize: const Size(0, 0),
      borderRadius: BorderRadius.circular(999),
      color: selected ? colors.textPrimary : colors.group,
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? colors.surface : colors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DashboardQuickRow extends StatelessWidget {
  const _DashboardQuickRow({
    required this.colors,
    required this.meta,
    required this.subtitle,
    required this.favorite,
    required this.onOpen,
    required this.onRename,
    required this.onDuplicate,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final _ApplePalette colors;
  final SheetMeta meta;
  final String subtitle;
  final bool favorite;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final title =
        meta.title.trim().isEmpty ? 'Planilla sin titulo' : meta.title;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      pressedOpacity: 0.55,
      onPressed: onOpen,
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
                    color: colors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: const Size(0, 0),
            onPressed: () async {
              await showCupertinoModalPopup<void>(
                context: context,
                builder: (ctx) => CupertinoActionSheet(
                  actions: [
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
                        onRename();
                      },
                      child: const Text('Renombrar'),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onDuplicate();
                      },
                      child: const Text('Duplicar'),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onToggleFavorite();
                      },
                      child: Text(
                        favorite
                            ? 'Quitar de favoritas'
                            : 'Marcar como favorita',
                      ),
                    ),
                    CupertinoActionSheetAction(
                      isDestructiveAction: true,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onDelete();
                      },
                      child: const Text('Eliminar'),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    isDefaultAction: true,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
              );
            },
            child: Icon(
              CupertinoIcons.ellipsis,
              color: colors.textSecondary,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateSearchResults extends StatelessWidget {
  const _TemplateSearchResults({
    required this.colors,
    required this.templates,
    required this.onOpenTemplate,
  });

  final _ApplePalette colors;
  final List<_PackTemplateSpec> templates;
  final ValueChanged<_PackTemplateSpec> onOpenTemplate;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return Text(
        'Sin plantillas para esta búsqueda.',
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plantillas',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < templates.length; i++) ...[
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 5),
            onPressed: () => onOpenTemplate(templates[i]),
            child: Row(
              children: [
                Icon(
                  templates[i].icon,
                  color: colors.accent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${templates[i].name} · ${templates[i].pack}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (i < templates.length - 1)
            Container(
              height: 1,
              color: colors.separator.withValues(
                alpha: colors.isLight ? 0.75 : 0.4,
              ),
            ),
        ],
      ],
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
    final iconColor =
        _isColorDark(item.iconBg) ? colors.surface : colors.textPrimary;
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
            child: Icon(item.icon, color: iconColor, size: 18),
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
    final scheme = Theme.of(context).colorScheme;
    final disabled = onTap == null;
    final iconColor = _isColorDark(color) ? scheme.onPrimary : scheme.onSurface;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Opacity(
      opacity: disabled ? 0.55 : 1.0,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        pressedOpacity: 0.65,
        onPressed: onTap,
        minimumSize: const Size(0, 0),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isLight ? 0.22 : 0.34),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(CupertinoIcons.add, color: iconColor, size: 28),
        ),
      ),
    );
  }
}

bool _isColorDark(Color color) => color.computeLuminance() < 0.45;

// ------------------------- Apple UI primitives -------------------------

class _ApplePalette {
  _ApplePalette({
    required this.isLight,
    required this.colorScheme,
    required this.scaffold,
  });

  final bool isLight;
  final ColorScheme colorScheme;
  final Color scaffold;

  Color get bg => scaffold;

  Color get surface => colorScheme.surface;

  Color get group => colorScheme.surfaceContainerHighest
      .withValues(alpha: isLight ? 0.72 : 0.56);

  Color get separator =>
      colorScheme.outlineVariant.withValues(alpha: isLight ? 0.84 : 0.72);

  Color get textPrimary => colorScheme.onSurface;

  Color get textSecondary =>
      colorScheme.onSurfaceVariant.withValues(alpha: isLight ? 0.90 : 0.94);

  Color get accent => colorScheme.primary;

  Color get muted =>
      colorScheme.onSurfaceVariant.withValues(alpha: isLight ? 0.72 : 0.78);

  Color get navBarBg =>
      colorScheme.surface.withValues(alpha: isLight ? 0.92 : 0.86);

  BoxShadow get subtleShadow => BoxShadow(
        color: colorScheme.shadow.withValues(alpha: isLight ? 0.10 : 0.36),
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

class _StartNotice {
  const _StartNotice({
    required this.message,
    required this.actionLabel,
    required this.detailsTitle,
    required this.detailsBody,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final String detailsTitle;
  final String detailsBody;
  final Future<void> Function() onAction;
}

class _NoticeArea extends StatelessWidget {
  const _NoticeArea({
    required this.colors,
    required this.notice,
    required this.onDetails,
  });

  final _ApplePalette colors;
  final _StartNotice notice;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return _AppleSectionCard(
      colors: colors,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              notice.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 0),
            borderRadius: BorderRadius.circular(999),
            color: colors.textPrimary,
            onPressed: () => unawaited(notice.onAction()),
            child: Text(
              notice.actionLabel,
              style: TextStyle(
                color: colors.surface,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            minimumSize: const Size(0, 0),
            onPressed: onDetails,
            child: Text(
              'Detalles',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreSheetItem {
  const _MoreSheetItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onSelected,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function() onSelected;
  final bool destructive;
}

class _MoreSheetRow extends StatelessWidget {
  const _MoreSheetRow({
    required this.colors,
    required this.item,
    required this.onTap,
  });

  final _ApplePalette colors;
  final _MoreSheetItem item;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final titleColor =
        item.destructive ? CupertinoColors.systemRed : colors.textPrimary;
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      onPressed: () => unawaited(onTap()),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: colors.group,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: colors.separator),
            ),
            child: Icon(item.icon, color: titleColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            color: colors.textSecondary,
            size: 14,
          ),
        ],
      ),
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
    final scheme = Theme.of(context).colorScheme;
    final bg =
        scheme.inverseSurface.withValues(alpha: widget.isLight ? 0.92 : 0.88);
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 160),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: scheme.shadow
                    .withValues(alpha: widget.isLight ? 0.22 : 0.36),
                blurRadius: 20,
                offset: Offset(0, 10)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          widget.message,
          style: TextStyle(
              color: scheme.onInverseSurface, fontWeight: FontWeight.w600),
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

class _ProLicenseCard extends StatelessWidget {
  const _ProLicenseCard({
    required this.colors,
    required this.busy,
    required this.releaseVersion,
    required this.demoModeEnabled,
    required this.demoSampleLoaded,
    required this.proExpanded,
    required this.proBenefitsExpanded,
    required this.demoExpanded,
    required this.showDemoSection,
    required this.onToggleProExpanded,
    required this.onToggleBenefits,
    required this.onToggleDemoExpanded,
    required this.onPrimaryCta,
    required this.onLoadDemo,
    required this.onRemoveDemo,
    required this.onToggleDemoMode,
  });

  final _ApplePalette colors;
  final bool busy;
  final String releaseVersion;
  final bool demoModeEnabled;
  final bool demoSampleLoaded;
  final bool proExpanded;
  final bool proBenefitsExpanded;
  final bool demoExpanded;
  final bool showDemoSection;
  final VoidCallback onToggleProExpanded;
  final VoidCallback onToggleBenefits;
  final VoidCallback onToggleDemoExpanded;
  final Future<void> Function() onPrimaryCta;
  final Future<void> Function() onLoadDemo;
  final Future<void> Function({bool notify}) onRemoveDemo;
  final Future<void> Function() onToggleDemoMode;

  @override
  Widget build(BuildContext context) {
    final benefits = <String>[
      'Exportaciones listas para cliente.',
      'Operacion offline con evidencia.',
      'Activacion comercial sin migraciones.',
    ];

    return _AppleSectionCard(
      colors: colors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DisclosureRow(
            key: const ValueKey('start-pro-disclosure'),
            title: 'Pro',
            subtitle: 'Version $releaseVersion',
            expanded: proExpanded,
            colors: colors,
            onTap: onToggleProExpanded,
          ),
          if (proExpanded) ...[
            const SizedBox(height: 8),
            Text(
              'Entrega profesional con menos friccion operativa.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            AppButton(
              label: 'Activar Pro',
              icon: CupertinoIcons.cart_fill_badge_plus,
              variant: AppButtonVariant.primary,
              onPressed: busy ? null : () => onPrimaryCta(),
            ),
            const SizedBox(height: 4),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
              minimumSize: const Size(0, 0),
              onPressed: onToggleBenefits,
              child: Text(
                proBenefitsExpanded ? 'Ocultar beneficios' : 'Ver beneficios',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (proBenefitsExpanded)
              Column(
                key: const ValueKey('start-pro-benefits'),
                children: [
                  for (final item in benefits)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            size: 14,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
          if (showDemoSection) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: colors.group.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.separator),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DisclosureRow(
                    key: const ValueKey('start-demo-disclosure'),
                    title: 'Demo',
                    subtitle: demoModeEnabled ? 'Activa' : 'Pausada',
                    expanded: demoExpanded,
                    colors: colors,
                    onTap: onToggleDemoExpanded,
                  ),
                  if (demoExpanded) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Prueba reversible para mostrar valor en minutos.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AppButton(
                          label: demoModeEnabled
                              ? 'Desactivar demo'
                              : 'Activar demo',
                          icon: demoModeEnabled
                              ? CupertinoIcons.eye_slash
                              : CupertinoIcons.play_circle,
                          variant: AppButtonVariant.ghost,
                          onPressed: busy ? null : () => onToggleDemoMode(),
                        ),
                        if (demoModeEnabled)
                          AppButton(
                            label: demoSampleLoaded
                                ? 'Quitar ejemplo'
                                : 'Probar demo',
                            icon: demoSampleLoaded
                                ? CupertinoIcons.trash
                                : CupertinoIcons.sparkles,
                            variant: AppButtonVariant.ghost,
                            onPressed: busy
                                ? null
                                : (demoSampleLoaded
                                    ? () => onRemoveDemo(notify: true)
                                    : () => onLoadDemo()),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DisclosureRow extends StatelessWidget {
  const _DisclosureRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.colors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool expanded;
  final _ApplePalette colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
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
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            expanded ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
            size: 16,
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _AppleEmptyState extends StatelessWidget {
  const _AppleEmptyState({
    required this.colors,
    required this.tab,
    required this.onNew,
    required this.onTemplate,
    required this.onImport,
    required this.onFolders,
    required this.isBusy,
  });

  final _ApplePalette colors;
  final _HomeTab tab;
  final Future<void> Function() onNew;
  final Future<void> Function() onTemplate;
  final Future<void> Function() onImport;
  final Future<void> Function() onFolders;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final title =
        tab == _HomeTab.trash ? 'Papelera vacía' : AppStrings.emptySheetsTitle;
    final msg = tab == _HomeTab.trash
        ? 'Las planillas movidas a papelera aparecen acá durante un tiempo para poder recuperarlas.'
        : AppStrings.emptySheetsBody;

    return AppCard(
      radius: 18,
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
            Text(
              'Inicio rápido: Crear planilla -> completar filas -> Exportar ZIP.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 10),
          if (tab == _HomeTab.sheets)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                Semantics(
                  label: AppStrings.semAddSheet,
                  button: true,
                  child: AppButton(
                    label: AppStrings.newSheet,
                    icon: CupertinoIcons.add,
                    variant: AppButtonVariant.primary,
                    onPressed: isBusy ? null : () => onNew(),
                  ),
                ),
                Semantics(
                  label: AppStrings.semTemplates,
                  button: true,
                  child: AppButton(
                    label: 'Probar demo',
                    icon: CupertinoIcons.square_grid_2x2,
                    variant: AppButtonVariant.secondary,
                    onPressed: isBusy ? null : () => onTemplate(),
                  ),
                ),
                AppButton(
                  label: 'Importar ZIP',
                  icon: CupertinoIcons.archivebox,
                  variant: AppButtonVariant.secondary,
                  onPressed: isBusy ? null : () => onImport(),
                ),
                AppButton(
                  label: 'Carpetas',
                  icon: CupertinoIcons.folder,
                  variant: AppButtonVariant.ghost,
                  onPressed: () => onFolders(),
                ),
              ],
            ),
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
    final theme = Theme.of(context);
    final pal = _ApplePalette(
      isLight: isLight,
      colorScheme: theme.colorScheme,
      scaffold: theme.scaffoldBackgroundColor,
    );

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
    final theme = Theme.of(context);
    final pal = _ApplePalette(
      isLight: isLight,
      colorScheme: theme.colorScheme,
      scaffold: theme.scaffoldBackgroundColor,
    );

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
        ? '${meta.rows} filas | ${fmt(meta.updatedAt)} | vence en ${daysLeftInTrash ?? 0} día(s)'
        : '${meta.rows} filas | ${fmt(meta.updatedAt)} | $folderName';

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
                ? '${meta.rows} filas | vence en ${daysLeftInTrash ?? 0} día(s)'
                : '${meta.rows} filas | $folderName',
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
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      minimumSize: const Size(0, 0),
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
    final theme = Theme.of(context);
    final pal = _ApplePalette(
      isLight: theme.brightness == Brightness.light,
      colorScheme: theme.colorScheme,
      scaffold: theme.scaffoldBackgroundColor,
    );
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
                '$count planilla(s) | creada ${_fmtFolderCreated(folder.createdAtMs)}'),
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
                  '$count planilla(s) | creada ${_fmtFolderCreated(folder.createdAtMs)}',
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

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
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
