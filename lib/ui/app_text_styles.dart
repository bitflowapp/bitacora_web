import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

@immutable
class AppTextStyles {
  const AppTextStyles(this._theme);

  final AppThemeData _theme;

  static AppTextStyles of(BuildContext context) {
    return AppTextStyles(AppTheme.of(context));
  }

  TextStyle get titleDisplay =>
      (_theme.text.displaySmall ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.4,
        height: 1.05,
      );

  TextStyle get titleLarge =>
      (_theme.text.titleLarge ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
      );

  TextStyle get titleMedium =>
      (_theme.text.titleMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.1,
      );

  TextStyle get bodyStrong =>
      (_theme.text.bodyMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w700,
      );

  TextStyle get bodyMuted =>
      (_theme.text.bodyMedium ?? const TextStyle()).copyWith(
        color: _theme.colors.textSecondary,
        fontWeight: FontWeight.w600,
      );

  TextStyle get labelStrong =>
      (_theme.text.labelLarge ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w800,
      );
}

extension AppTextStylesX on BuildContext {
  AppTextStyles get appText => AppTextStyles.of(this);
}
