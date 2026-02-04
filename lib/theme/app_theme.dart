import 'package:flutter/material.dart';

import 'gridnote_theme.dart';

@immutable
class AppRadii {
  const AppRadii({
    this.xs = 8,
    this.sm = 12,
    this.md = 16,
    this.lg = 20,
    this.xl = 26,
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
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.xxl = 32,
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
    final scheme = theme.colorScheme;

    final bg = theme.scaffoldBackgroundColor;
    final surface = theme.cardColor;
    final surfaceMuted =
        isLight ? const Color(0xFFF2F2F4) : const Color(0xFF0F1114);
    final surfaceElevated =
        isLight ? const Color(0xFFFFFFFF) : const Color(0xFF15181D);

    final border = (theme.dividerColor).withOpacity(isLight ? 0.9 : 0.65);
    final borderStrong = scheme.outline.withOpacity(isLight ? 0.95 : 0.75);

    final accent = scheme.primary;
    final accentMuted = accent.withOpacity(isLight ? 0.12 : 0.18);

    final statusBg = accent.withOpacity(isLight ? 0.10 : 0.16);
    final statusFg = accent.withOpacity(isLight ? 0.95 : 0.85);

    final warningBg =
        isLight ? const Color(0xFFFFF7ED) : const Color(0xFF3A2414);
    final warningFg =
        isLight ? const Color(0xFF9A3412) : const Color(0xFFFBBF24);

    final dangerBg =
        isLight ? const Color(0xFFFEE2E2) : const Color(0xFF3B0A0A);
    final dangerFg =
        isLight ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5);

    final successBg =
        isLight ? const Color(0xFFECFDF3) : const Color(0xFF102617);
    final successFg =
        isLight ? const Color(0xFF166534) : const Color(0xFF86EFAC);

    final hover = (isLight ? Colors.black : Colors.white)
        .withOpacity(isLight ? 0.04 : 0.08);
    final pressed = (isLight ? Colors.black : Colors.white)
        .withOpacity(isLight ? 0.08 : 0.14);
    final focusRing = accent.withOpacity(isLight ? 0.24 : 0.32);

    final colors = AppColors(
      isLight: isLight,
      bg: bg,
      surface: surface,
      surfaceMuted: surfaceMuted,
      surfaceElevated: surfaceElevated,
      border: border,
      borderStrong: borderStrong,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
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

    final shadowColor =
        Colors.black.withOpacity(isLight ? 0.10 : 0.60);
    final softShadow =
        Colors.black.withOpacity(isLight ? 0.06 : 0.40);

    final shadows = AppShadows(
      card: [
        BoxShadow(
          color: shadowColor,
          blurRadius: isLight ? 14 : 22,
          offset: const Offset(0, 8),
        ),
      ],
      soft: [
        BoxShadow(
          color: softShadow,
          blurRadius: isLight ? 10 : 16,
          offset: const Offset(0, 5),
        ),
      ],
      floating: [
        BoxShadow(
          color: shadowColor,
          blurRadius: isLight ? 20 : 30,
          offset: const Offset(0, 12),
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
