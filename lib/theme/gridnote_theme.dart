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

    // Premium B2B table — base surfaces lifted off pure white/black,
    // stronger jerarquía between header / row / alt row, delicate borders.
    final cellBg = isLight
        ? AppColors.lightBg
        // Lift cells off OLED true black so empty cells don't read as a bug.
        : AppColors.darkSecondaryBg;

    final headerBase = isLight
        // Slightly stronger header on light to separate from page bg.
        ? AppColors.lightTertiaryBg
        : AppColors.darkTertiaryBg;
    final headerBg = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.04 : 0.08),
      headerBase,
    );

    final zebraColor = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.022 : 0.060),
      isLight ? AppColors.lightSecondaryBg : AppColors.darkTertiaryBg,
    );

    // Borders: delicate but visible — premium feel, not hairline ghost.
    final gridLine = isLight
        ? Color.alphaBlend(
            AppColors.lightOpaqueSeparator.withValues(alpha: 0.55),
            AppColors.lightDivider,
          )
        : Color.alphaBlend(
            AppColors.darkOpaqueSeparator.withValues(alpha: 0.45),
            AppColors.darkDivider,
          );

    final headerText = isLight
        ? scheme.onSurface.withValues(alpha: 0.78)
        : scheme.onSurface.withValues(alpha: 0.90);
    final secondaryLabel = isLight
        ? scheme.onSurface.withValues(alpha: 0.58)
        : scheme.onSurfaceVariant;
    final bodyText = scheme.onSurface.withValues(alpha: isLight ? 0.94 : 0.96);

    // Selection: present but not aggressive. Slightly stronger in dark.
    final selectionBg = accent.withValues(alpha: isLight ? 0.12 : 0.22);
    final hoverBg = accent.withValues(alpha: isLight ? 0.045 : 0.10);
    final focusRing = accent.withValues(alpha: isLight ? 0.62 : 0.85);

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
        height: 1.32,
        letterSpacing: -0.04,
      ),
      headerTextStyle: AppTypography.caption1.copyWith(
        color: headerText,
        fontWeight: FontWeight.w800,
        fontSize: 11.5,
        height: 1.18,
        letterSpacing: 0.46,
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
