import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

@immutable
class BitflowSpacing {
  const BitflowSpacing();

  final double s4 = 4;
  final double s8 = 8;
  final double s12 = 12;
  final double s16 = 16;
  final double s24 = 24;
  final double s32 = 32;
}

@immutable
class BitflowRadii {
  const BitflowRadii();

  final double sm = 12;
  final double md = 16;
  final double lg = 20;
  final double pill = 999;
}

@immutable
class BitflowShadows {
  const BitflowShadows({required this.isLight});

  final bool isLight;

  List<BoxShadow> get level1 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.28),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];

  List<BoxShadow> get level2 => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isLight ? 0.12 : 0.34),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];
}

@immutable
class BitflowTypography {
  const BitflowTypography({
    required this.textTheme,
    required this.primary,
    required this.secondary,
  });

  final TextTheme textTheme;
  final Color primary;
  final Color secondary;

  TextStyle get title => (textTheme.titleLarge ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.24,
        height: 1.12,
        color: primary,
      );

  TextStyle get body => (textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: primary,
      );

  TextStyle get caption => (textTheme.bodySmall ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.08,
        color: secondary,
      );
}

@immutable
class BitflowTokens {
  const BitflowTokens._(this._theme);

  static const BitflowSpacing spacing = BitflowSpacing();
  static const BitflowRadii radii = BitflowRadii();
  static const double minTapTarget = 44;

  final AppThemeData _theme;

  static BitflowTokens of(BuildContext context) {
    return BitflowTokens._(AppTheme.of(context));
  }

  AppColors get colors => _theme.colors;

  BitflowTypography get typography => BitflowTypography(
        textTheme: _theme.text,
        primary: _theme.colors.textPrimary,
        secondary: _theme.colors.textSecondary,
      );

  BitflowShadows get shadows => BitflowShadows(isLight: _theme.colors.isLight);
}

extension BitflowTokensX on BuildContext {
  BitflowTokens get bitflow => BitflowTokens.of(this);
}
