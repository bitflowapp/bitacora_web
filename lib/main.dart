// lib/main.dart
//
// Gridnote / BitFlow — Main
// - Fix definitivo de Zone mismatch (ensureInitialized y runApp en la MISMA zone)
// - Boot no bloqueante (Firebase + SheetStore) con modo demo si Firebase falla
// - Theme light/dark con toggle
// - Scroll behavior consistente (mouse/touch/trackpad) + physics iOS bounce
//
// Requiere:
//   firebase_core
//   (firebase_options.dart generado por FlutterFire)
//   services/sheet_store.dart
//   screens/auth_gate.dart
//   screens/start_page.dart
//   widgets/animated_video_background.dart

import 'dart:async';
import 'dart:ui' show PointerDeviceKind, PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'firebase_options.dart';
import 'screens/auth_gate.dart';
import 'screens/start_page.dart';
import 'services/sheet_store.dart';
import 'widgets/animated_video_background.dart';

void main() {
  // Debe setearse ANTES de inicializar el binding (y dentro de la misma zone).
  runZonedGuarded(() {
    if (kDebugMode) {
      // En debug: si hay un problema de zones, que explote acá y no “medio ande”.
      BindingBase.debugZoneErrorsAreFatal = true;
    }

    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
        // ignore: avoid_print
        print(details.exception);
        // ignore: avoid_print
        print(details.stack);
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('Uncaught error: $error');
        // ignore: avoid_print
        print(stack);
      }
      // true = lo marcamos como “handled” para evitar crash en web.
      return true;
    };

    runApp(const App());
  }, (Object error, StackTrace stack) {
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
  late bool _isLight;
  late Future<_BootStatus> _bootFuture;

  @override
  void initState() {
    super.initState();

    final platformBrightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    _isLight = platformBrightness != Brightness.dark;

    // Boot async no bloqueante: dejamos renderizar UI inmediatamente.
    _bootFuture = _boot();
  }

  Future<_BootStatus> _boot() async {
    bool firebaseOk = false;
    bool storeOk = false;
    Object? firebaseError;
    Object? storeError;

    // 1) Firebase (si falla: modo demo, NO bloquea UI)
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 10));
      firebaseOk = true;
    } catch (e) {
      firebaseOk = false;
      firebaseError = e;
    }

    // 2) Store local (si falla: seguimos igual)
    try {
      await SheetStore.init().timeout(const Duration(seconds: 6));
      storeOk = true;
    } catch (e) {
      storeOk = false;
      storeError = e;
    }

    return _BootStatus(
      firebaseOk: firebaseOk,
      storeOk: storeOk,
      firebaseError: firebaseError,
      storeError: storeError,
    );
  }

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFF0A84FF); // azul Apple/Gridnote

    final lightTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: baseColor,
      brightness: Brightness.light,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: const Color(0xFFF5F5FA),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        isDense: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: baseColor,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      scaffoldBackgroundColor: const Color(0xFF050816),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        isDense: true,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gridnote',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _isLight ? ThemeMode.light : ThemeMode.dark,
      scrollBehavior: const _AppScrollBehavior(),
      home: AnimatedVideoBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: FutureBuilder<_BootStatus>(
            future: _bootFuture,
            builder: (context, snap) {
              final isWaiting =
                  snap.connectionState == ConnectionState.waiting ||
                      snap.connectionState == ConnectionState.active;

              if (isWaiting) {
                return _BootSplash(
                  isLight: _isLight,
                  onToggleTheme: _toggleTheme,
                  subtitle: 'Inicializando…',
                );
              }

              final status = snap.data ??
                  const _BootStatus(
                    firebaseOk: false,
                    storeOk: false,
                  );

              // Si Firebase falló: modo demo para probar UI sin bloquear.
              if (!status.firebaseOk) {
                return _BootSplash(
                  isLight: _isLight,
                  onToggleTheme: _toggleTheme,
                  subtitle: 'Modo demo (Firebase no inició)',
                  details: _formatBootErrors(status),
                  actions: [
                    _PillButton(
                      label: 'Reintentar',
                      onPressed: () {
                        setState(() {
                          _bootFuture = _boot();
                        });
                      },
                    ),
                    const SizedBox(width: 10),
                    _PillButton(
                      label: 'Entrar igual',
                      outlined: true,
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => AnimatedVideoBackground(
                              child: Scaffold(
                                backgroundColor: Colors.transparent,
                                body: StartPage(
                                  isLight: _isLight,
                                  onToggleTheme: _toggleTheme,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              }

              // Firebase OK: flujo normal con AuthGate.
              return AuthGate(
                child: StartPage(
                  isLight: _isLight,
                  onToggleTheme: _toggleTheme,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _toggleTheme() {
    setState(() {
      _isLight = !_isLight;
    });
  }

  String _formatBootErrors(_BootStatus s) {
    final lines = <String>[];
    if (!s.firebaseOk && s.firebaseError != null) {
      lines.add('Firebase: ${s.firebaseError}');
    }
    if (!s.storeOk && s.storeError != null) {
      lines.add('Store: ${s.storeError}');
    }
    return lines.join('\n').trim();
  }
}

class _BootSplash extends StatelessWidget {
  const _BootSplash({
    required this.isLight,
    required this.onToggleTheme,
    required this.subtitle,
    this.details,
    this.actions,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;
  final String subtitle;
  final String? details;
  final List<Widget>? actions;

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
                          label: isLight ? 'Noche' : 'Día',
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
                          details!.trim(),
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
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Si esto tarda, es init/red/cache. Lo importante: no queda “infinito” sin UI.',
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
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
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
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
