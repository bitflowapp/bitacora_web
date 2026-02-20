import 'dart:async';
import 'dart:ui' show PointerDeviceKind, PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

import 'config/feature_flags.dart';
import 'core/app_error.dart';
import 'firebase_options.dart';
import 'core/sync/sync_bootstrap.dart';
import 'screens/auth_gate.dart';
import 'screens/editor_screen.dart';
import 'screens/editor_perf_harness_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/legal_screen.dart';
import 'start_page.dart';
import 'services/app_error_reporter.dart';
import 'services/sheet_store.dart';
import 'services/engine_math_client.dart'; // si lo seguis usando en otras partes
import 'services/engine_client.dart'; // <-- NUEVO (EngineConfig / EngineClient)
import 'services/engine_config.dart' as engine_cfg;
import 'services/demo_templates.dart';
import 'widgets/animated_video_background.dart';
import 'ui/app_error_boundary.dart';
import 'ui/ui_theme.dart';

const String kBuildBadgeId =
    String.fromEnvironment('BUILD_ID', defaultValue: '');
const bool kShowBuildBadge = bool.fromEnvironment(
  'SHOW_BUILD_BADGE',
  defaultValue: false,
);

final GlobalKey<AppErrorBoundaryState> _appErrorBoundaryKey =
    GlobalKey<AppErrorBoundaryState>();

void _reportGlobalError(
  Object error,
  StackTrace stackTrace, {
  required String operation,
}) {
  try {
    final appError = AppErrorMapper.from(
      error,
      flow: AppErrorFlow.load,
      fallbackMessage: 'Se detecto un error inesperado.',
    );
    AppErrorReporter.I.record(
      appError,
      operation: operation,
      stackTrace: stackTrace,
    );
  } catch (_) {}
  _appErrorBoundaryKey.currentState?.capture(error, stackTrace);
}

Future<void> _applyEngineBaseUrlOverrideFromUrl() async {
  // Soporta Web iPhone / Android / Desktop. En nativo suele no venir query param, pero no rompe.
  final raw = Uri.base.queryParameters['engine'];
  if (raw == null) return;

  final url = raw.trim();
  if (url.isEmpty) return;

  try {
    // 1) Si tu app todavia usa EngineMathClient en otros lugares, mantenemos este override.
    await EngineMathClient().setBaseUrl(url);

    // 2) Y tambien persistimos para el EngineConfig (engine_client.dart),
    //    asi el EditorScreen grande usa el mismo baseUrl.
    await EngineConfig.instance.setOverride(url);

    final normalized = engine_cfg.EngineConfig.normalize(url);
    if (engine_cfg.EngineConfig.isValidBaseUrl(normalized)) {
      await engine_cfg.EngineConfig.instance.setManualBaseUrl(normalized);
      await engine_cfg.EngineConfig.instance
          .setMode(engine_cfg.EngineConfig.modeManual);
      await engine_cfg.EngineConfig.instance.setLastResolved(normalized);
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print('[main] Engine baseUrl override via ?engine= -> $url');
    }
  } catch (e) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[main] Invalid ?engine= value: $e');
    }
  }
}

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      _reportGlobalError(
        details.exception,
        details.stack ?? StackTrace.current,
        operation: 'flutter_error',
      );
      if (kDebugMode) {
        // ignore: avoid_print
        print(details.exception);
        // ignore: avoid_print
        print(details.stack);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _reportGlobalError(error, stack, operation: 'platform_dispatcher');
      if (kDebugMode) {
        // ignore: avoid_print
        print('Uncaught error: $error');
        // ignore: avoid_print
        print(stack);
      }
      return true;
    };

    ErrorWidget.builder = (FlutterErrorDetails details) {
      // UI controlada (en vez de pantalla roja en produccion web)
      return Material(
        color: const Color(0xFF0B0D1A),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xCC0B0D1A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x22FFFFFF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      height: 1.25,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gridnote - Error',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFamily: null,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(details.exceptionAsString()),
                        if (kDebugMode && details.stack != null) ...[
                          const SizedBox(height: 10),
                          Text(details.stack.toString()),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    };

    runApp(
      AppErrorBoundary(
        key: _appErrorBoundaryKey,
        child: const App(),
      ),
    );
    // Persistimos override de engine en background para no bloquear primera pintura.
    unawaited(_applyEngineBaseUrlOverrideFromUrl());
  }, (error, stack) {
    _reportGlobalError(error, stack, operation: 'zone_guarded');
    if (kDebugMode) {
      // ignore: avoid_print
      print('Zoned error: $error');
      // ignore: avoid_print
      print(stack);
    }
  });
}

class _BootStatus {
  const _BootStatus({
    required this.firebaseOk,
    required this.storeOk,
    this.firebaseError,
    this.storeError,
  });

  final bool firebaseOk;
  final bool storeOk;
  final Object? firebaseError;
  final Object? storeError;
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  static const Duration _bootWatchdogDelay = Duration(seconds: 14);

  late bool _isLight;
  late Future<_BootStatus> _bootFuture;
  Timer? _bootWatchdogTimer;
  bool _bootWatchdogTriggered = false;
  GoRouter? _router;

  @override
  void initState() {
    super.initState();

    final platformBrightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    _isLight = platformBrightness != Brightness.dark;

    // No bloqueamos el primer frame: boot asincrono + watchdog.
    _startBoot();
  }

  @override
  void dispose() {
    _bootWatchdogTimer?.cancel();
    super.dispose();
  }

  void _startBoot() {
    _bootWatchdogTimer?.cancel();
    _bootWatchdogTriggered = false;
    _bootFuture = _boot().whenComplete(() {
      _bootWatchdogTimer?.cancel();
    });
    _bootWatchdogTimer = Timer(_bootWatchdogDelay, () {
      if (!mounted) return;
      setState(() {
        _bootWatchdogTriggered = true;
      });
      if (kDebugMode) {
        debugPrint('[boot] watchdog triggered after $_bootWatchdogDelay');
      }
    });
  }

  Future<_BootStatus> _boot() async {
    bool firebaseOk = false;
    bool storeOk = false;
    Object? firebaseError;
    Object? storeError;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 10));
      firebaseOk = true;
    } catch (e) {
      firebaseOk = false;
      firebaseError = e;
    }

    try {
      await SheetStore.init().timeout(const Duration(seconds: 6));
      storeOk = true;
    } catch (e) {
      storeOk = false;
      storeError = e;
    }

    try {
      await initSyncLayer().timeout(const Duration(seconds: 4));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[boot] Sync layer init failed: $e');
      }
    }

    try {
      await AppErrorReporter.I.init().timeout(const Duration(seconds: 2));
    } catch (_) {}
    // EngineConfig en background: no bloquea primera pintura.
    unawaited(_initEngineConfigNonBlocking());

    return _BootStatus(
      firebaseOk: firebaseOk,
      storeOk: storeOk,
      firebaseError: firebaseError,
      storeError: storeError,
    );
  }

  Future<void> _initEngineConfigNonBlocking() async {
    try {
      await EngineConfig.instance
          .init(
            timeout: const Duration(seconds: 6),
            versionJsonPath: 'version.json',
          )
          .timeout(const Duration(seconds: 7));
      if (kDebugMode) {
        debugPrint('[boot] Engine baseUri = ${EngineConfig.instance.baseUri}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[boot] EngineConfig init failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = UiTheme.light();
    final darkTheme = UiTheme.dark();
    final shouldShowBadge = kDebugMode && kShowBuildBadge;

    Widget wrapWithBuildBadge(Widget child) {
      if (!shouldShowBadge) return child;
      return Stack(
        fit: StackFit.expand,
        children: [
          child,
          const _BuildBadge(),
        ],
      );
    }

    Widget buildBoot(Widget child) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Bitacora Web',
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: _isLight ? ThemeMode.light : ThemeMode.dark,
        scrollBehavior: const _AppScrollBehavior(),
        builder: (context, child) {
          return wrapWithBuildBadge(child ?? const SizedBox.shrink());
        },
        home: AnimatedVideoBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: child,
          ),
        ),
      );
    }

    return FutureBuilder<_BootStatus>(
      future: _bootFuture,
      builder: (context, snap) {
        final isWaiting = snap.connectionState == ConnectionState.waiting ||
            snap.connectionState == ConnectionState.active;

        if (isWaiting) {
          if (_bootWatchdogTriggered) {
            return buildBoot(
              _BootSplash(
                isLight: _isLight,
                onToggleTheme: _toggleTheme,
                subtitle: 'Inicio demorado. La UI sigue en modo seguro.',
                details:
                    'El arranque tardo mas de ${_bootWatchdogDelay.inSeconds}s.\nPuedes reintentar sin recargar.',
                showProgress: false,
                actions: [
                  _PillButton(
                    label: 'Reintentar inicio',
                    onPressed: () => setState(_startBoot),
                  ),
                ],
              ),
            );
          }
          return buildBoot(
            _BootSplash(
              isLight: _isLight,
              onToggleTheme: _toggleTheme,
              subtitle: 'Inicializando...',
            ),
          );
        }

        final status =
            snap.data ?? const _BootStatus(firebaseOk: false, storeOk: false);
        if (!status.storeOk) {
          return buildBoot(
            _BootSplash(
              isLight: _isLight,
              onToggleTheme: _toggleTheme,
              subtitle: 'Almacenamiento no inicio',
              details: _formatBootErrors(status),
              actions: [
                _PillButton(
                  label: 'Reintentar',
                  onPressed: () {
                    setState(_startBoot);
                  },
                ),
              ],
            ),
          );
        }

        _router ??= _buildRouter(status);

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Bitacora Web',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: _isLight ? ThemeMode.light : ThemeMode.dark,
          scrollBehavior: const _AppScrollBehavior(),
          builder: (context, child) {
            return wrapWithBuildBadge(child ?? const SizedBox.shrink());
          },
          routerConfig: _router!,
        );
      },
    );
  }

  GoRouter _buildRouter(_BootStatus status) {
    return GoRouter(
      initialLocation: '/',
      errorBuilder: (context, state) => _RouteErrorScreen(
        location: state.uri.toString(),
        isLight: _isLight,
        onToggleTheme: _toggleTheme,
      ),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => buildRootPageForUri(
            uri: state.uri,
            isLight: _isLight,
            onToggleTheme: _toggleTheme,
            firebaseOk: status.firebaseOk,
          ),
        ),
        GoRoute(
          path: '/app',
          builder: (context, state) => _AppHome(
            isLight: _isLight,
            onToggleTheme: _toggleTheme,
            firebaseOk: status.firebaseOk,
          ),
        ),
        GoRoute(
          path: '/perf',
          builder: (context, state) => EditorPerfHarnessScreen(
            isLight: _isLight,
            onToggleTheme: _toggleTheme,
          ),
        ),
        GoRoute(
          path: '/privacy',
          builder: (context, state) => const LegalScreen.privacy(),
        ),
        GoRoute(
          path: '/terms',
          builder: (context, state) => const LegalScreen.terms(),
        ),
      ],
    );
  }

  void _toggleTheme() {
    setState(() => _isLight = !_isLight);
  }

  String _formatBootErrors(_BootStatus s) {
    final lines = <String>[];
    if (!s.firebaseOk && s.firebaseError != null) {
      lines.add('Firebase: ${s.firebaseError}');
    }
    if (!s.storeOk && s.storeError != null) {
      lines.add('Store: ${s.storeError}');
    }
    return lines.join('\n');
  }
}

Widget buildRootPageForUri({
  required Uri uri,
  required bool isLight,
  required VoidCallback onToggleTheme,
  required bool firebaseOk,
}) {
  final template = resolveDemoTemplateFromSlug(uri.queryParameters['template']);
  if (template != null) {
    return _AppHome(
      isLight: isLight,
      onToggleTheme: onToggleTheme,
      firebaseOk: firebaseOk,
      initialTemplate: template,
    );
  }
  if (!kAuthEnabled) {
    return _AppHome(
      isLight: isLight,
      onToggleTheme: onToggleTheme,
      firebaseOk: firebaseOk,
    );
  }
  return LandingScreen(
    isLight: isLight,
    onToggleTheme: onToggleTheme,
  );
}

class _AppHome extends StatelessWidget {
  const _AppHome({
    required this.isLight,
    required this.onToggleTheme,
    required this.firebaseOk,
    this.initialTemplate,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;
  final bool firebaseOk;
  final DemoTemplateSpec? initialTemplate;

  @override
  Widget build(BuildContext context) {
    Widget withOptionalAuth(Widget child) {
      if (!kAuthEnabled) return child;
      if (!firebaseOk) return child;
      return AuthGate(child: child);
    }

    final home = () {
      if (initialTemplate != null) {
        final template = initialTemplate!;
        return withOptionalAuth(
          EditorScreen(
            isLight: isLight,
            onToggleTheme: onToggleTheme,
            sheetId:
                'demo_${template.slug}_${DateTime.now().millisecondsSinceEpoch}',
            initialName: template.sheetName,
            initialHeaders: template.headers,
            initialRows: template.rows,
          ),
        );
      }
      return withOptionalAuth(
        StartPage(
          isLight: isLight,
          onToggleTheme: onToggleTheme,
        ),
      );
    }();

    final body = AnimatedVideoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: home,
      ),
    );

    if (firebaseOk || !kAuthEnabled) return body;
    return Stack(
      children: [
        body,
        const _TopNotice(
          message: 'Firebase no inicio. Modo offline habilitado.',
        ),
      ],
    );
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash({
    required this.isLight,
    required this.onToggleTheme,
    required this.subtitle,
    this.details,
    this.actions,
    this.showProgress = true,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;
  final String subtitle;
  final String? details;
  final List<Widget>? actions;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cardBg = theme.brightness == Brightness.dark
        ? const Color(0xCC0B0D1A)
        : const Color(0xCCFFFFFF);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Card(
              elevation: 0,
              color: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0x22FFFFFF)
                      : const Color(0x14000000),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: cs.primary.withOpacity(0.14),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Gridnote',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        _PillButton(
                          label: isLight ? 'Noche' : 'D\u00EDa',
                          outlined: true,
                          onPressed: onToggleTheme,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withOpacity(0.78),
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if ((details ?? '').trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: theme.brightness == Brightness.dark
                              ? const Color(0x14000000)
                              : const Color(0x0A000000),
                          border: Border.all(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0x22FFFFFF)
                                : const Color(0x14000000),
                          ),
                        ),
                        child: Text(
                          details!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            height: 1.2,
                            color: cs.onSurface.withOpacity(0.78),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        if (showProgress) ...[
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                        ] else ...[
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: cs.onSurface.withOpacity(0.7),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            showProgress
                                ? 'Inicializando en segundo plano.'
                                : 'Sin spinner infinito: puedes reintentar sin recargar.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withOpacity(0.7),
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (actions != null) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: actions!,
                      ),
                    ],
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

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
      side: outlined
          ? BorderSide(
              color: theme.brightness == Brightness.dark
                  ? const Color(0x33FFFFFF)
                  : const Color(0x22000000),
            )
          : BorderSide.none,
    );

    final style = ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      shape: WidgetStateProperty.all(shape),
      elevation: WidgetStateProperty.all(0),
      backgroundColor: outlined
          ? WidgetStateProperty.all(Colors.transparent)
          : WidgetStateProperty.all(cs.primary.withOpacity(0.14)),
      foregroundColor:
          WidgetStateProperty.all(outlined ? cs.onSurface : cs.primary),
      overlayColor: WidgetStateProperty.all(cs.primary.withOpacity(0.10)),
    );

    return TextButton(
      onPressed: onPressed,
      style: style,
      child: Text(
        label,
        style:
            theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TopNotice extends StatelessWidget {
  const _TopNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.surface.withOpacity(0.92),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 16,
                    offset: Offset(0, 8),
                    color: Color(0x22000000),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
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

class _BuildBadge extends StatelessWidget {
  const _BuildBadge();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    final shortestSide = mq?.size.shortestSide ?? 1024;
    final hideOnCompactUi = shortestSide < 700;
    if (hideOnCompactUi) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final label = kBuildBadgeId.trim().isEmpty
        ? (kDebugMode ? 'build dev' : 'build')
        : 'build ${kBuildBadgeId.trim()}';

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 10, top: 10),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.74),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.dividerColor.withOpacity(0.35)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({
    required this.location,
    required this.isLight,
    required this.onToggleTheme,
  });

  final String location;
  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    return AnimatedVideoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _BootSplash(
          isLight: isLight,
          onToggleTheme: onToggleTheme,
          subtitle: 'No encontramos esa ruta',
          details:
              'La URL solicitada no existe en esta version.\nRuta: $location',
          showProgress: false,
          actions: [
            _PillButton(
              label: 'Ir al inicio',
              onPressed: () => context.go('/'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => <PointerDeviceKind>{
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.unknown,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final platform = getPlatform(context);
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics());
    }
    return const ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}
