// lib/theme/gridnote_theme.dart
import 'package:flutter/material.dart';

/// Gridnote — Theme Controller + Apple Premium Theme
///
/// Objetivo:
// - Look Apple “premium” (cálido, limpio, sin tinta Material fuerte)
// - Botones píldora, cards suaves, bordes sutiles, overlays controlados
// - Soporte claro/oscuro consistente
// - Estilo de tabla/grilla derivado (zebra + líneas finas)

class GridnoteThemeController extends ChangeNotifier {
  GridnoteThemeController({bool light = true}) : _light = light;

  bool _light;

  bool get isLight => _light;

  GridnoteTheme get theme => GridnoteTheme.build(_light);

  void setLight(bool v) {
    if (_light == v) return;
    _light = v;
    notifyListeners();
  }

  void toggle() => setLight(!_light);
}

int _a(double opacity) {
  final v = (opacity * 255).round();
  if (v <= 0) return 0;
  if (v >= 255) return 255;
  return v;
}

Color _mix(Color a, Color b, double t) {
  // t 0..1
  final tt = t.clamp(0.0, 1.0);
  int lerpInt(int x, int y) => x + ((y - x) * tt).round();

  return Color.fromARGB(
    lerpInt(a.alpha, b.alpha),
    lerpInt(a.red, b.red),
    lerpInt(a.green, b.green),
    lerpInt(a.blue, b.blue),
  );
}

/// Paleta/tema efectivo para Gridnote.
class GridnoteTheme {
  const GridnoteTheme({
    required this.material,
    required this.scaffold,
    required this.card,
    required this.divider,
    required this.accent,
  });

  final ThemeData material;
  final Color scaffold;
  final Color card;
  final Color divider;
  final Color accent;

  static GridnoteTheme build(bool light) {
    // Acento iOS-like.
    const accentBlue = Color(0xFF0A84FF);

    // “Warm Apple” (beige/arena) para que se sienta premium.
    // Si querés más frío, cambiá scaffoldLight a 0xFFF5F5F7 y listo.
    const scaffoldLight = Color(0xFFF7F4EE);
    const scaffoldDark = Color(0xFF050A14);

    const cardLight = Color(0xFFFFFFFF);
    const cardDark = Color(0xFF0B1220);

    const dividerLight = Color(0xFFE6E2DA);
    const dividerDark = Color(0xFF1E293B);

    final brightness = light ? Brightness.light : Brightness.dark;

    final baseScheme = ColorScheme.fromSeed(
      seedColor: accentBlue,
      brightness: brightness,
    );

    final scaffold = light ? scaffoldLight : scaffoldDark;

    // “Glass” muy sutil: card con alpha apenas, para no ensuciar lectura.
    final card = (light ? cardLight : cardDark).withAlpha(_a(light ? 0.985 : 0.97));

    final divider = light ? dividerLight : dividerDark;

    // Overlays controlados: esto es lo que más “delata” Material si no lo tocás.
    final overlayPressed =
    (light ? Colors.black : Colors.white).withAlpha(_a(light ? 0.06 : 0.08));
    final overlayHover =
    (light ? Colors.black : Colors.white).withAlpha(_a(light ? 0.035 : 0.05));
    final overlayFocusRing = accentBlue.withAlpha(_a(light ? 0.22 : 0.28));

    // Tonos secundarios para headers/variants.
    final surfaceVariant = light ? const Color(0xFFF3F1EC) : const Color(0xFF0F172A);
    final onSurfaceVariant =
    (light ? const Color(0xFF111827) : const Color(0xFFE5E7EB))
        .withAlpha(_a(light ? 0.78 : 0.82));

    final scheme = baseScheme.copyWith(
      primary: accentBlue,
      secondary: accentBlue,
      background: scaffold,
      surface: card,
      surfaceContainerHighest: card,
      surfaceVariant: surfaceVariant,
      onSurfaceVariant: onSurfaceVariant,
      outline: divider.withAlpha(_a(light ? 0.90 : 0.70)),
      outlineVariant: divider.withAlpha(_a(light ? 0.86 : 0.60)),
    );

    // Tipografía base estilo iOS (cupertino typography) pero usable en Material.
    final cupertinoText = light ? Typography.blackCupertino : Typography.whiteCupertino;

    final textTheme = cupertinoText.copyWith(
      titleLarge: cupertinoText.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: cupertinoText.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      titleSmall: cupertinoText.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.0,
      ),
      bodyLarge: cupertinoText.bodyLarge?.copyWith(
        height: 1.25,
      ),
      bodyMedium: cupertinoText.bodyMedium?.copyWith(
        height: 1.22,
      ),
      bodySmall: cupertinoText.bodySmall?.copyWith(
        height: 1.18,
      ),
      labelLarge: cupertinoText.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    const pillShape = StadiumBorder();

    // Transiciones tipo iOS en todas las plataformas: se siente “premium” rápido.
    const pageTransitions = PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    );

    // Colores para inputs (más iOS, menos “caja Material”).
    final inputFill = light
        ? _mix(Colors.white, scaffold, 0.06).withAlpha(_a(0.96))
        : Colors.white.withAlpha(_a(0.06));

    final material = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      cardColor: card,
      dividerColor: divider,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      pageTransitionsTheme: pageTransitions,

      // Tipos: si no tenés SF Pro embebida, cae al fallback sin romper.
      fontFamily: 'SF Pro Text',
      fontFamilyFallback: const [
        'SF Pro Text',
        'SF Pro Display',
        'Inter',
        'Roboto',
        'Segoe UI',
        'Helvetica',
        'Arial',
      ],
      textTheme: textTheme,

      // Menos “tinta Material”.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,

      // Focus / selección / cursor (clave para que deje de parecer Flutter stock).
      focusColor: overlayFocusRing,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentBlue,
        selectionColor: accentBlue.withAlpha(_a(0.22)),
        selectionHandleColor: accentBlue,
      ),

      // AppBar plano, Apple-like (sin tint ni elevaciones raras).
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scaffold.withAlpha(_a(light ? 0.90 : 0.93)),
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(
          color: scheme.onSurface,
          size: 20,
        ),
      ),

      // Cards: borde sutil, radio grande, sombra limpia.
      cardTheme: CardThemeData(
        margin: const EdgeInsets.all(10),
        elevation: light ? 1.25 : 3.0,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
        shadowColor: (light ? Colors.black : Colors.black).withAlpha(_a(0.12)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(
            color: divider.withAlpha(_a(light ? 0.75 : 0.55)),
            width: 0.85,
          ),
        ),
      ),

      // Diálogos tipo “sheet” elegante.
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: light ? 2.0 : 6.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: divider.withAlpha(_a(light ? 0.80 : 0.50)),
            width: 0.8,
          ),
        ),
        titleTextStyle: textTheme.titleSmall?.copyWith(
          color: scheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface.withAlpha(_a(0.86)),
        ),
      ),

      // Inputs: relleno suave + borde fino.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: divider.withAlpha(_a(light ? 0.80 : 0.55)),
            width: 0.9,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: divider.withAlpha(_a(light ? 0.80 : 0.55)),
            width: 0.9,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: accentBlue.withAlpha(_a(0.92)),
            width: 1.35,
          ),
        ),
      ),

      // Botones: píldora + overlay sutil (pressed/hover).
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          shape: const MaterialStatePropertyAll(pillShape),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          ),
          textStyle: MaterialStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          overlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) return overlayPressed;
            if (states.contains(MaterialState.hovered)) return overlayHover;
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: const MaterialStatePropertyAll(pillShape),
          side: MaterialStatePropertyAll(
            BorderSide(color: divider.withAlpha(_a(light ? 0.78 : 0.55))),
          ),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          ),
          textStyle: MaterialStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          overlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) return overlayPressed;
            if (states.contains(MaterialState.hovered)) return overlayHover;
            return null;
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: const MaterialStatePropertyAll(pillShape),
          padding: const MaterialStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          ),
          textStyle: MaterialStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          overlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) return overlayPressed;
            if (states.contains(MaterialState.hovered)) return overlayHover;
            return null;
          }),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: const MaterialStatePropertyAll(pillShape),
          padding: const MaterialStatePropertyAll(EdgeInsets.all(10)),
          overlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) return overlayPressed;
            if (states.contains(MaterialState.hovered)) return overlayHover;
            return null;
          }),
        ),
      ),

      // Switch/Checkbox “calmados”.
      switchTheme: SwitchThemeData(
        trackOutlineColor: MaterialStatePropertyAll(
          divider.withAlpha(_a(light ? 0.70 : 0.50)),
        ),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return accentBlue.withAlpha(_a(light ? 0.30 : 0.42));
          }
          return divider.withAlpha(_a(light ? 0.28 : 0.34));
        }),
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return accentBlue;
          return light ? Colors.white : const Color(0xFF0F172A);
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: divider.withAlpha(_a(light ? 0.80 : 0.58))),
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return accentBlue;
          return Colors.transparent;
        }),
        checkColor: const MaterialStatePropertyAll(Colors.white),
      ),

      // Chips “pill” premium.
      chipTheme: ChipThemeData(
        shape: pillShape,
        side: BorderSide(color: divider.withAlpha(_a(light ? 0.78 : 0.55))),
        backgroundColor: scheme.surfaceVariant.withAlpha(_a(light ? 0.65 : 0.55)),
        selectedColor: accentBlue.withAlpha(_a(light ? 0.14 : 0.18)),
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),

      // Menús: borde fino + radio grande.
      popupMenuTheme: PopupMenuThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: light ? 6 : 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: divider.withAlpha(_a(light ? 0.78 : 0.55))),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),

      // Tooltip “calmo”.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: (light ? Colors.black : Colors.white).withAlpha(_a(0.90)),
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: TextStyle(
          color: light ? Colors.white : Colors.black,
          fontWeight: FontWeight.w700,
        ),
      ),

      // SnackBars tipo pill, flotantes.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
        (light ? Colors.black : Colors.white).withAlpha(_a(0.90)),
        contentTextStyle: TextStyle(
          color: light ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // BottomSheet tipo “sheet” iOS.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        elevation: light ? 10 : 16,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),

      // NavigationBar más “iOS-like”.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card.withAlpha(_a(light ? 0.94 : 0.92)),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentBlue.withAlpha(_a(light ? 0.12 : 0.18)),
        labelTextStyle: MaterialStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          final selected = states.contains(MaterialState.selected);
          return IconThemeData(
            color: selected ? accentBlue : scheme.onSurfaceVariant,
            size: 22,
          );
        }),
      ),

      // ListTile “Settings-like”.
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Progreso/spinners.
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentBlue,
        linearTrackColor: Color(0x220A84FF),
      ),

      // Scrollbars discretas.
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(12),
        thickness: const MaterialStatePropertyAll(9),
        thumbVisibility: const MaterialStatePropertyAll(true),
      ),

      // Dividers finos (grilla).
      dividerTheme: DividerThemeData(
        color: divider.withAlpha(_a(light ? 0.90 : 0.65)),
        thickness: 0.8,
        space: 1,
      ),
    );

    return GridnoteTheme(
      material: material,
      scaffold: scaffold,
      card: card,
      divider: divider,
      accent: accentBlue,
    );
  }
}

/// Estilo de la tabla (encabezado, líneas y celdas) derivado del tema.
/// Incluye `zebra` y `zebraColor` para compatibilidad con SmartDataSource.
@immutable
class GridnoteTableStyle {
  const GridnoteTableStyle({
    this.zebra = true,
    this.zebraColor = const Color(0x0C000000),
    required this.headerBg,
    required this.headerText,
    required this.gridLine,
    required this.cellBg,
    this.cellTextStyle,
    this.headerTextStyle,
  });

  final bool zebra;
  final Color zebraColor;

  final Color headerBg;
  final Color headerText;
  final Color gridLine;
  final Color cellBg;

  final TextStyle? cellTextStyle;
  final TextStyle? headerTextStyle;

  factory GridnoteTableStyle.from(GridnoteTheme g) {
    final isLight = g.material.brightness == Brightness.light;
    final divider = g.divider;

    final headerBg = isLight
        ? const Color(0xFFFBFAF7) // cálido, premium
        : const Color(0xFF0F172A);

    final cellBg = g.card;

    return GridnoteTableStyle(
      zebra: true,
      zebraColor: divider.withAlpha(_a(isLight ? 0.10 : 0.18)),
      headerBg: headerBg,
      headerText: isLight ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      gridLine: divider.withAlpha(_a(isLight ? 0.88 : 0.62)),
      cellBg: cellBg,
      cellTextStyle: g.material.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      headerTextStyle: g.material.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.12,
      ),
    );
  }

  GridnoteTableStyle copyWith({
    bool? zebra,
    Color? zebraColor,
    Color? headerBg,
    Color? headerText,
    Color? gridLine,
    Color? cellBg,
    TextStyle? cellTextStyle,
    TextStyle? headerTextStyle,
  }) {
    return GridnoteTableStyle(
      zebra: zebra ?? this.zebra,
      zebraColor: zebraColor ?? this.zebraColor,
      headerBg: headerBg ?? this.headerBg,
      headerText: headerText ?? this.headerText,
      gridLine: gridLine ?? this.gridLine,
      cellBg: cellBg ?? this.cellBg,
      cellTextStyle: cellTextStyle ?? this.cellTextStyle,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
    );
  }
}
