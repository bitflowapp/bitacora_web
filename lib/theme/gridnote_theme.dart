// lib/theme/gridnote_theme.dart
import 'package:flutter/material.dart';

/// Controlador de tema Gridnote (claro/oscuro).
class GridnoteThemeController extends ChangeNotifier {
  GridnoteThemeController({bool light = true}) : _light = light;
  bool _light;

  GridnoteTheme get theme => _build(_light);

  void setLight(bool v) {
    if (_light == v) return;
    _light = v;
    notifyListeners();
  }

  void toggle() => setLight(!_light);

  GridnoteTheme _build(bool light) {
    const blue = Color(0xFF0A84FF);

    final brightness = light ? Brightness.light : Brightness.dark;

    final baseScheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: brightness,
    );

    // Fondo tipo Apple / Gridnote
    final scaffold = light
        ? const Color(0xFFF5F5F7) // gris Apple claro
        : const Color(0xFF020617); // azul-negrito profundo

    // Cards con efecto “glass” suave
    final cardBase = light ? Colors.white : const Color(0xFF020617);
    final card = cardBase.withValues(alpha: light ? 0.98 : 0.96);

    // Divisores / líneas de grilla
    final divider = light
        ? const Color(0xFFE5E5EA)
        : const Color(0xFF1E293B);

    final scheme = baseScheme.copyWith(
      background: scaffold,
      surface: card,
      surfaceContainerHighest: card,
      outlineVariant: divider,
    );

    final material = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      scaffoldBackgroundColor: scaffold,
      cardColor: card,
      dividerColor: divider,
      visualDensity: VisualDensity.compact,
      fontFamily: 'SF Pro Text',
      fontFamilyFallback: const [
        'SF Pro Text',
        'Inter',
        'Roboto',
        'Segoe UI',
        'Helvetica',
        'Arial',
      ],

      // AppBar tipo iOS: plano, sin brillo raro.
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: scaffold.withValues(alpha: light ? 0.92 : 0.94),
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),

      // Cards redondeadas con borde sutil (usa CardThemeData, no CardTheme).
      cardTheme: CardThemeData(
        margin: const EdgeInsets.all(8),
        elevation: light ? 1.5 : 3,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: divider.withValues(alpha: light ? 0.85 : 0.7),
            width: 0.8,
          ),
        ),
      ),

      // Diálogos con look de hoja flotante (DialogThemeData).
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: divider.withValues(alpha: light ? 0.9 : 0.5),
            width: 0.7,
          ),
        ),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: 14,
          color: scheme.onSurface.withValues(alpha: 0.85),
        ),
      ),

      // Inputs compactos, con bordes suaves.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: light
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: divider.withValues(alpha: light ? 0.9 : 0.6),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: divider.withValues(alpha: light ? 0.9 : 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: blue.withValues(alpha: 0.9),
            width: 1.4,
          ),
        ),
        isDense: true,
      ),

      // SnackBars flotantes tipo “pill”.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: (light ? Colors.black : Colors.white)
            .withValues(alpha: 0.9),
        contentTextStyle: TextStyle(
          color: light ? Colors.white : Colors.black,
        ),
      ),

      // BottomSheet con borde redondeado superior (para plantillas, etc.).
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );

    return GridnoteTheme(
      material: material,
      scaffold: scaffold,
      card: card,
      divider: divider,
    );
  }
}

/// Paleta/tema efectivo para Gridnote.
class GridnoteTheme {
  const GridnoteTheme({
    required this.material,
    required this.scaffold,
    required this.card,
    required this.divider,
  });

  final ThemeData material;
  final Color scaffold;
  final Color card;
  final Color divider;
}

/// Estilo de la tabla (encabezado, líneas y celdas) derivado del tema.
/// Incluye `zebra` y `zebraColor` para compatibilidad con SmartDataSource.
@immutable
class GridnoteTableStyle {
  const GridnoteTableStyle({
    // Nuevos (para SmartDataSource):
    this.zebra = true,
    this.zebraColor = const Color(0x0C000000),

    // Existentes en tu versión:
    required this.headerBg,
    required this.headerText,
    required this.gridLine,
    required this.cellBg,

    // Opcionales extra por si querés tipografías personalizadas:
    this.cellTextStyle,
    this.headerTextStyle,
  });

  /// Rayado alternado de filas.
  final bool zebra;

  /// Color de fondo para filas “zebra”.
  final Color zebraColor;

  /// Fondo de encabezado.
  final Color headerBg;

  /// Color de texto del encabezado.
  final Color headerText;

  /// Color de líneas de la grilla.
  final Color gridLine;

  /// Fondo de celdas.
  final Color cellBg;

  /// (Opcional) Estilo de texto de celda.
  final TextStyle? cellTextStyle;

  /// (Opcional) Estilo de texto de encabezado.
  final TextStyle? headerTextStyle;

  /// Crea el estilo derivado del tema global.
  factory GridnoteTableStyle.from(GridnoteTheme g) {
    final isLight = g.material.brightness == Brightness.light;
    final divider = g.divider;

    return GridnoteTableStyle(
      zebra: true,
      zebraColor:
      divider.withValues(alpha: isLight ? 0.08 : 0.14), // rayado suave
      headerBg: isLight
          ? const Color(0xFFF9FAFB)
          : const Color(0xFF111827),
      headerText: isLight ? const Color(0xFF111827) : Colors.white,
      gridLine: divider.withValues(alpha: isLight ? 0.9 : 0.6),
      cellBg: g.card,
      cellTextStyle: g.material.textTheme.bodyMedium,
      headerTextStyle: g.material.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
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
