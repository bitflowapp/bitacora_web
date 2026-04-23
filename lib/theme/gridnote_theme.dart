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
    final headerBg =
        isLight ? const Color(0xFFFFFFFF) : const Color(0xFF111827);
    final cellBg = isLight ? const Color(0xFFFFFFFF) : const Color(0xFF0B0F14);
    final label = isLight ? const Color(0xFF111827) : AppColors.darkLabel;
    final headerText =
        isLight ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final secondaryLabel =
        isLight ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
    final gridLine =
        isLight ? const Color(0xFFE5E7EB) : const Color(0xFF253041);

    return GridnoteTableStyle(
      zebra: true,
      zebraColor: isLight ? const Color(0xFFF9FAFB) : const Color(0xFF111827),
      headerBg: headerBg,
      headerText: headerText,
      gridLine: gridLine,
      cellBg: cellBg,
      cellTextStyle: AppTypography.body.copyWith(
        color: label,
        fontWeight: FontWeight.w400,
        fontSize: 13.5,
        letterSpacing: -0.05,
      ),
      headerTextStyle: AppTypography.footnote.copyWith(
        color: secondaryLabel,
        fontWeight: FontWeight.w600,
        fontSize: 11.5,
        letterSpacing: 0.5,
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
