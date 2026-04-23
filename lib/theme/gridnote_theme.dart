// lib/theme/gridnote_theme.dart
import 'package:flutter/material.dart';

import 'package:bitacora_web/design_system/colors.dart';
import 'package:bitacora_web/design_system/theme_data.dart';
import 'package:bitacora_web/design_system/typography.dart';

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
    final material = light ? AppThemeBuilder.light() : AppThemeBuilder.dark();
    return GridnoteTheme(
      material: material,
      scaffold: material.scaffoldBackgroundColor,
      card: material.cardColor,
      divider: material.dividerColor,
      accent: light ? AppColors.accentBlue : AppColors.accentBlueDark,
    );
  }
}

/// Estilo de la tabla (encabezado, líneas y celdas) derivado del tema.
/// Incluye `zebra` y `zebraColor` para compatibilidad con SmartDataSource.
@immutable
class GridnoteTableStyle {
  const GridnoteTableStyle({
    this.zebra = true,
    required this.zebraColor,
    required this.headerBg,
    required this.headerText,
    required this.gridLine,
    required this.cellBg,
    required this.selectionBg,
    required this.hoverBg,
    required this.focusRing,
    required this.rowIndexText,
    required this.rowIndexSelectedText,
    required this.cursorColor,
    this.cellTextStyle,
    this.headerTextStyle,
  });

  final bool zebra;
  final Color zebraColor;

  final Color headerBg;
  final Color headerText;
  final Color gridLine;
  final Color cellBg;
  final Color selectionBg;
  final Color hoverBg;
  final Color focusRing;
  final Color rowIndexText;
  final Color rowIndexSelectedText;
  final Color cursorColor;

  final TextStyle? cellTextStyle;
  final TextStyle? headerTextStyle;

  factory GridnoteTableStyle.from(GridnoteTheme g) {
    final theme = g.material;
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final accent = g.accent;

    final cellBg = isLight ? AppColors.lightBg : AppColors.darkBg;
    final headerBase =
        isLight ? AppColors.lightSecondaryBg : AppColors.darkSecondaryBg;
    final headerBg = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.026 : 0.060),
      headerBase,
    );
    final zebraColor = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.014 : 0.050),
      isLight ? AppColors.lightBg : AppColors.darkSecondaryBg,
    );
    final gridLine = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.028 : 0.055),
      g.divider.withValues(alpha: isLight ? 0.96 : 0.90),
    );
    final headerText = isLight
        ? scheme.onSurface.withValues(alpha: 0.74)
        : scheme.onSurface.withValues(alpha: 0.86);
    final secondaryLabel = isLight
        ? scheme.onSurface.withValues(alpha: 0.54)
        : scheme.onSurfaceVariant;
    final bodyText = scheme.onSurface.withValues(alpha: isLight ? 0.92 : 0.94);
    final selectionBg = accent.withValues(alpha: isLight ? 0.10 : 0.18);
    final hoverBg = accent.withValues(alpha: isLight ? 0.035 : 0.085);
    final focusRing = accent.withValues(alpha: isLight ? 0.58 : 0.80);

    return GridnoteTableStyle(
      zebra: true,
      zebraColor: zebraColor,
      headerBg: headerBg,
      headerText: headerText,
      gridLine: gridLine,
      cellBg: cellBg,
      selectionBg: selectionBg,
      hoverBg: hoverBg,
      focusRing: focusRing,
      rowIndexText: secondaryLabel,
      rowIndexSelectedText: accent,
      cursorColor: accent,
      cellTextStyle: AppTypography.footnote.copyWith(
        color: bodyText,
        fontWeight: FontWeight.w500,
        fontSize: 13.5,
        height: 1.28,
        letterSpacing: -0.04,
      ),
      headerTextStyle: AppTypography.caption1.copyWith(
        color: headerText,
        fontWeight: FontWeight.w700,
        fontSize: 11.5,
        height: 1.18,
        letterSpacing: 0.42,
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
    Color? selectionBg,
    Color? hoverBg,
    Color? focusRing,
    Color? rowIndexText,
    Color? rowIndexSelectedText,
    Color? cursorColor,
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
      selectionBg: selectionBg ?? this.selectionBg,
      hoverBg: hoverBg ?? this.hoverBg,
      focusRing: focusRing ?? this.focusRing,
      rowIndexText: rowIndexText ?? this.rowIndexText,
      rowIndexSelectedText: rowIndexSelectedText ?? this.rowIndexSelectedText,
      cursorColor: cursorColor ?? this.cursorColor,
      cellTextStyle: cellTextStyle ?? this.cellTextStyle,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
    );
  }
}
