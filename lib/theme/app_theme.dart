import 'package:flutter/material.dart';

import 'package:bitacora_web/design_system/colors.dart' as ds;

import 'gridnote_theme.dart';

@immutable
class AppRadii {
  const AppRadii({
    this.xs = 10,
    this.sm = 14,
    this.md = 18,
    this.lg = 22,
    this.xl = 28,
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
    this.xs = 6,
    this.sm = 10,
    this.md = 14,
    this.lg = 20,
    this.xl = 28,
    this.xxl = 36,
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

    final brightness = isLight ? Brightness.light : Brightness.dark;
    final bg = ds.AppColors.bg(brightness);
    final surface = ds.AppColors.bg(brightness);
    final surfaceMuted = ds.AppColors.secondaryBg(brightness);
    final surfaceElevated =
        isLight ? ds.AppColors.lightBg : ds.AppColors.darkTertiaryBg;

    final neutralInk = ds.AppColors.label(brightness);
    final neutralMuted = ds.AppColors.secondaryLabel(brightness);
    final border = ds.AppColors.divider(brightness);
    final borderStrong = isLight
        ? ds.AppColors.lightOpaqueSeparator
        : ds.AppColors.darkOpaqueSeparator;

    final accent = ds.AppColors.accent(brightness);
    final accentMuted = accent.withValues(alpha: isLight ? 0.07 : 0.16);

    final statusBg = accent.withValues(alpha: isLight ? 0.08 : 0.16);
    final statusFg = neutralInk;

    final warningBg =
        (isLight ? ds.AppColors.accentOrange : ds.AppColors.accentOrangeDark)
            .withValues(alpha: isLight ? 0.12 : 0.18);
    final warningFg =
        isLight ? ds.AppColors.accentOrange : ds.AppColors.accentOrangeDark;

    final dangerBg =
        (isLight ? ds.AppColors.accentRed : ds.AppColors.accentRedDark)
            .withValues(alpha: isLight ? 0.10 : 0.18);
    final dangerFg =
        isLight ? ds.AppColors.accentRed : ds.AppColors.accentRedDark;

    final successBg =
        (isLight ? ds.AppColors.accentGreen : ds.AppColors.accentGreenDark)
            .withValues(alpha: isLight ? 0.10 : 0.18);
    final successFg =
        isLight ? ds.AppColors.accentGreen : ds.AppColors.accentGreenDark;

    final hover = (isLight ? Colors.black : Colors.white)
        .withValues(alpha: isLight ? 0.035 : 0.07);
    final pressed = (isLight ? Colors.black : Colors.white)
        .withValues(alpha: isLight ? 0.09 : 0.15);
    final focusRing = accent.withValues(alpha: isLight ? 0.28 : 0.40);

    final colors = AppColors(
      isLight: isLight,
      bg: bg,
      surface: surface,
      surfaceMuted: surfaceMuted,
      surfaceElevated: surfaceElevated,
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

    final shadowColor = Colors.black.withValues(alpha: isLight ? 0.10 : 0.48);
    final softShadow = Colors.black.withValues(alpha: isLight ? 0.05 : 0.34);

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
