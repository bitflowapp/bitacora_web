import 'package:flutter/material.dart';

import 'gridnote_theme.dart';

@immutable
class AppRadii {
  const AppRadii({
    this.xs = 12,
    this.sm = 16,
    this.md = 22,
    this.lg = 28,
    this.xl = 34,
    this.pill = 999,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double pill;
}

@immutable
class AppSpacing {
  const AppSpacing({
    this.xs = 8,
    this.sm = 12,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
    this.xxl = 42,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
}

@immutable
class AppShadows {
  const AppShadows({
    required this.card,
    required this.soft,
    required this.floating,
  });

  final List<BoxShadow> card;
  final List<BoxShadow> soft;
  final List<BoxShadow> floating;
}

@immutable
class AppColors {
  const AppColors({
    required this.isLight,
    required this.bg,
    required this.surface,
    required this.surfaceMuted,
    required this.surfaceElevated,
    required this.chromeGray,
    required this.chromeGrayAlt,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.accentMuted,
    required this.statusBg,
    required this.statusFg,
    required this.warningBg,
    required this.warningFg,
    required this.dangerBg,
    required this.dangerFg,
    required this.successBg,
    required this.successFg,
    required this.hover,
    required this.pressed,
    required this.focusRing,
  });

  final bool isLight;
  final Color bg;
  final Color surface;
  final Color surfaceMuted;
  final Color surfaceElevated;
  final Color chromeGray;
  final Color chromeGrayAlt;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color accentMuted;
  final Color statusBg;
  final Color statusFg;
  final Color warningBg;
  final Color warningFg;
  final Color dangerBg;
  final Color dangerFg;
  final Color successBg;
  final Color successFg;
  final Color hover;
  final Color pressed;
  final Color focusRing;
}

@immutable
class AppThemeData {
  const AppThemeData({
    required this.material,
    required this.colors,
    required this.radii,
    required this.spacing,
    required this.shadows,
    required this.text,
  });

  final ThemeData material;
  final AppColors colors;
  final AppRadii radii;
  final AppSpacing spacing;
  final AppShadows shadows;
  final TextTheme text;
}

class AppTheme {
  static ThemeData material(bool light) => GridnoteTheme.build(light).material;

  static AppThemeData of(BuildContext context) {
    return fromTheme(Theme.of(context));
  }

  static AppThemeData fromTheme(ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;

    final bg = isLight ? const Color(0xFFF6EEE4) : const Color(0xFF17120E);
    final surface = isLight ? const Color(0xFFFFFCF8) : const Color(0xFF211A15);
    final surfaceMuted = isLight
        ? const Color(0xFFF1E7D8)
        : const Color(0xFF2A231E);
    final surfaceElevated = isLight
        ? const Color(0xFFFFF8F1)
        : const Color(0xFF241D18);
    const chromeGray = Color(0xFFEFE2D1);
    const chromeGrayAlt = Color(0xFFF6EEE3);

    final neutralInk = isLight
        ? const Color(0xFF2B241E)
        : const Color(0xFFF5EEE5);
    final neutralMuted = isLight
        ? const Color(0xFF6C5E50)
        : const Color(0xFFC8BBAD);
    final border = isLight ? const Color(0xFFE3D4C2) : const Color(0xFF3A3028);
    final borderStrong = isLight
        ? const Color(0xFFD5C2AD)
        : const Color(0xFF4B3E34);

    final accent = neutralInk;
    final accentMuted = accent.withValues(alpha: isLight ? 0.07 : 0.16);

    final statusBg = accent.withValues(alpha: isLight ? 0.08 : 0.16);
    final statusFg = neutralInk;

    final warningBg = surfaceMuted;
    final warningFg = neutralInk;

    final dangerBg = isLight
        ? const Color(0xFFF4E7E3)
        : const Color(0xFF32231F);
    final dangerFg = neutralInk;

    final successBg = isLight
        ? const Color(0xFFEAF0E5)
        : const Color(0xFF263022);
    final successFg = neutralInk;

    final hover = (isLight ? Colors.black : Colors.white).withValues(
      alpha: isLight ? 0.035 : 0.07,
    );
    final pressed = (isLight ? Colors.black : Colors.white).withValues(
      alpha: isLight ? 0.09 : 0.15,
    );
    final focusRing = accent.withValues(alpha: isLight ? 0.28 : 0.40);

    final colors = AppColors(
      isLight: isLight,
      bg: bg,
      surface: surface,
      surfaceMuted: surfaceMuted,
      surfaceElevated: surfaceElevated,
      chromeGray: isLight ? chromeGray : const Color(0xFF202226),
      chromeGrayAlt: isLight ? chromeGrayAlt : const Color(0xFF1A1C20),
      border: border,
      borderStrong: borderStrong,
      textPrimary: neutralInk,
      textSecondary: neutralMuted,
      accent: accent,
      accentMuted: accentMuted,
      statusBg: statusBg,
      statusFg: statusFg,
      warningBg: warningBg,
      warningFg: warningFg,
      dangerBg: dangerBg,
      dangerFg: dangerFg,
      successBg: successBg,
      successFg: successFg,
      hover: hover,
      pressed: pressed,
      focusRing: focusRing,
    );

    final radii = const AppRadii();
    final spacing = const AppSpacing();

    final shadowColor = const Color(
      0xFF2D2218,
    ).withValues(alpha: isLight ? 0.11 : 0.34);
    final softShadow = const Color(
      0xFF2D2218,
    ).withValues(alpha: isLight ? 0.06 : 0.24);

    final shadows = AppShadows(
      card: [
        BoxShadow(
          color: shadowColor,
          blurRadius: isLight ? 18 : 24,
          offset: const Offset(0, 10),
        ),
      ],
      soft: [
        BoxShadow(
          color: softShadow,
          blurRadius: isLight ? 12 : 18,
          offset: const Offset(0, 6),
        ),
      ],
      floating: [
        BoxShadow(
          color: shadowColor,
          blurRadius: isLight ? 24 : 30,
          offset: const Offset(0, 14),
        ),
      ],
    );

    return AppThemeData(
      material: theme,
      colors: colors,
      radii: radii,
      spacing: spacing,
      shadows: shadows,
      text: theme.textTheme,
    );
  }
}
