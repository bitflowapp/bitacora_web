import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/sheet_store.dart';
import 'screens/auth_gate.dart';
import 'screens/start_page.dart';
import 'widgets/animated_video_background.dart';

void main() {
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

  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Uncaught error: $error');
      // ignore: avoid_print
      print(stack);
    }
    return true;
  };

  runZonedGuarded(() {
    runApp(const App());
  }, (error, stack) {
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

    // IMPORTANTÍSIMO: NO bloquear el primer frame con awaits.
    _bootFuture = _boot();
  }

  Future<_BootStatus> _boot() async {
    bool firebaseOk = false;
    bool storeOk = false;
    Object? firebaseError;
    Object? storeError;

    // 1) Firebase (si falla, NO bloquea la app: habilitamos modo demo)
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseOk = true;
    } catch (e) {
      firebaseOk = false;
      firebaseError = e;
    }

    // 2) Store local (si falla, seguimos igual)
    try {
      await SheetStore.init();
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
    const baseColor = Color(0xFF0A84FF); // azul tipo Apple/Gridnote

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
                // Ya NO hay “loading infinito del index.html”: esto es UI real.
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
                        // Entramos directo sin AuthGate.
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
    if (lines.isEmpty) return '';
    return lines.join('\n');
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
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Si esto tarda, no es tu UI: es init/red/cache. Ahora al menos se ve y no queda “infinito”.',
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
        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
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
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
