// lib/app.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/auth_gate.dart';
import 'start_page.dart';
import 'theme/app_theme.dart';
import 'theme/gridnote_theme.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Scroll “Apple-like”:
/// - sin glow de Android
/// - drag con mouse/trackpad/stylus (web/desktop)
class _AppleScrollBehavior extends MaterialScrollBehavior {
  const _AppleScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const _kThemeModeKey = 'gridnote_theme_mode'; // 0=system, 1=light, 2=dark

  // Cache: construir temas una sola vez (menos GC/rebuilds).
  late final ThemeData _lightTheme;
  late final ThemeData _darkTheme;

  // Preferencia persistida
  ThemeMode _themeMode = ThemeMode.system;
  bool _prefsReady = false;

  // Controller (por si lo usás en widgets legacy; mantiene API compatible).
  final GridnoteThemeController _controller = GridnoteThemeController(light: true);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _lightTheme = AppTheme.material(true);
    _darkTheme = AppTheme.material(false);

    _initPrefs();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Si estás en system, el OS cambió: reconstruimos para reflejarlo.
    if (_themeMode == ThemeMode.system && mounted) setState(() {});
  }

  Future<void> _initPrefs() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final v = sp.getInt(_kThemeModeKey);

      ThemeMode mode;
      if (v == 1) {
        mode = ThemeMode.light;
      } else if (v == 2) {
        mode = ThemeMode.dark;
      } else {
        mode = ThemeMode.system;
      }

      // Sin flash raro: setState una sola vez.
      if (!mounted) return;
      setState(() {
        _themeMode = mode;
        _prefsReady = true;
      });

      // Mantener controller alineado (por compatibilidad con pantallas viejas).
      _controller.setLight(_effectiveIsLight(mode));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _themeMode = ThemeMode.system;
        _prefsReady = true;
      });
      _controller.setLight(_effectiveIsLight(ThemeMode.system));
    }
  }

  bool _effectiveIsLight(ThemeMode mode) {
    if (mode == ThemeMode.light) return true;
    if (mode == ThemeMode.dark) return false;

    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return platformBrightness != Brightness.dark;
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final v = switch (mode) {
        ThemeMode.system => 0,
        ThemeMode.light => 1,
        ThemeMode.dark => 2,
      };
      await sp.setInt(_kThemeModeKey, v);
    } catch (_) {
      // No es crítico; no bloqueamos UX.
    }
  }

  void _toggleTheme() {
    // Apple premium: si el usuario está en "system", el primer toggle “fija”
    // el modo opuesto al actual. Luego alterna light/dark normalmente.
    final effectiveLight = _effectiveIsLight(_themeMode);

    final next = (_themeMode == ThemeMode.system)
        ? (effectiveLight ? ThemeMode.dark : ThemeMode.light)
        : (_themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);

    setState(() => _themeMode = next);

    _controller.setLight(_effectiveIsLight(next));
    _saveThemeMode(next);
  }

  @override
  Widget build(BuildContext context) {
    // Evita el “flash” al arrancar (web/desktop) mostrando fondo correcto.
    final effectiveLight = _effectiveIsLight(_themeMode);
    final g = GridnoteTheme.build(effectiveLight);

    return ColoredBox(
      color: g.scaffold,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          // Preferimos ThemeMode real para que system sea “premium”.
          final mode = _prefsReady ? _themeMode : ThemeMode.system;
          final isLight = _effectiveIsLight(mode);

          final gg = GridnoteTheme.build(isLight);

          return MaterialApp(
            title: 'BitFlow',
            debugShowCheckedModeBanner: false,
            scrollBehavior: const _AppleScrollBehavior(),

            theme: _lightTheme,
            darkTheme: _darkTheme,
            themeMode: mode,

            // Cambio de tema con sensación premium.
            themeAnimationDuration: const Duration(milliseconds: 220),
            themeAnimationCurve: Curves.easeOutCubic,

            // Fondo correcto durante el build (reduce “pantallazo blanco”).
            builder: (context, child) {
              final c = child ?? const SizedBox.shrink();
              return ColoredBox(color: gg.scaffold, child: c);
            },

            home: AuthGate(
              child: StartPage(
                isLight: isLight,
                onToggleTheme: _toggleTheme,
              ),
            ),
          );
        },
      ),
    );
  }
}




