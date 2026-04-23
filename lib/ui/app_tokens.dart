import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_text_styles.dart';

@immutable
class AppTokens {
  const AppTokens(this._theme);

  final AppThemeData _theme;

  static AppTokens of(BuildContext context) => AppTokens(AppTheme.of(context));

  AppColors get colors => _theme.colors;
  AppRadii get radii => _theme.radii;
  AppLayout get spacing => _theme.spacing;
  AppShadows get shadows => _theme.shadows;
  TextTheme get text => _theme.text;
  AppTextStyles get textStyles => AppTextStyles(_theme);
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => AppTokens.of(this);
}
