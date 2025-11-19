import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/sheet_store.dart';
import 'screens/auth_gate.dart';
import 'screens/start_page.dart';
import 'widgets/animated_video_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (bitacora-28be4, generado por FlutterFire CLI).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Store de planillas (SharedPreferences en IO / localStorage en Web).
  await SheetStore.init();

  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late bool _isLight;

  @override
  void initState() {
    super.initState();
    // Arranca siguiendo el tema del SO (se puede cambiar con el botón).
    final platformBrightness =
        SchedulerBinding.instance.platformDispatcher.platformBrightness;
    _isLight = platformBrightness != Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    const baseColor = Color(0xFF0A84FF); // azul tipo Apple/Gridnote

    // Tema claro bien “día”
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

    // Tema oscuro bien marcado
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
          body: AuthGate(
            child: StartPage(
              isLight: _isLight,
              onToggleTheme: () {
                setState(() {
                  _isLight = !_isLight;
                });
              },
            ),
          ),
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
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    // Un poco más “rápido” y suave en el resto (Android, Windows, Web, etc.).
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }
}
