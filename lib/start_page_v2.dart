// ignore_for_file: unused_element
// lib/start_page.dart
// StartPage (BitFlow) - Home "100% Apple" (Cupertino-first), robusto y vendible.
//
// UPDATE (menu estilo Reminders iOS):
// - Agrega dashboard superior: tarjetas Hoy/Programados/Todos/Con indicador/Terminados.
// - Agrega Lista sugerida + Mis listas (Raiz + Carpetas + Papelera).
// - Barra superior en pÃƒÆ’Ã‚Â­ldora (Buscar / Nuevo / MÃƒÆ’Ã‚Â¡s) como Reminders.
// - BotÃƒÆ’Ã‚Â³n flotante iOS (+) abajo a la derecha (NO Material FAB).
//
// FIX ENGINE (apunta al puerto):
// - Default inteligente: usa el MISMO host donde abriste la web + :8001 (en desktop: localhost -> 8001; en iPhone/Android: IP LAN -> 8001).
// - Normaliza lo que pegÃƒÆ’Ã‚Â¡s: elimina /healthz, /docs, #/..., ?... y deja solo scheme://host:port.
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
        FilledButton,
        OutlinedButton,
        ListTile,
        Ink,
        InkWell,
        MaterialPageRoute,
        LicensePage,
        Scaffold,
        showModalBottomSheet,
        showDialog;
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:archive/archive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import 'core/app_error.dart';
import 'ui/ui.dart';
import 'workers/json_worker.dart';
import 'services/app_error_reporter.dart';
import 'services/engine_api.dart';
import 'services/engine_config.dart';
import 'services/export_filename.dart';
import 'services/export_flow_outcome.dart';
import 'services/sheet_store.dart';
import 'models/cell_ref.dart';
import 'models/cell_meta.dart';
import 'models/table_state.dart';
import 'services/export_xlsx_service.dart';
import 'services/build_info.dart';
import 'services/attachment_store.dart';
import 'services/audio_storage_service.dart';
import 'services/audio_service.dart';
import 'screens/about_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/terms_screen.dart';
import 'services/auth_service.dart';
import 'services/bitflow_feature_service.dart';
import 'services/bitflow_product_models.dart';
import 'services/bitflow_product_service.dart';
import 'services/runtime_flags.dart';
import 'widgets/command_palette.dart';
import 'widgets/pro_upgrade_sheet.dart';

part 'start_v2_body.dart';
part 'start_v2_header_section.dart';
part 'start_v2_more_sheet.dart';
part 'start_v2_primary_actions_section.dart';
part 'start_v2_recent_section.dart';
part 'start_v2_shared_widgets.dart';
part 'start_v2_suggestions_section.dart';
part 'start_v2_support_widgets.dart';
