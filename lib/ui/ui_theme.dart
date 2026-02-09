import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class UiTheme {
  static ThemeData light() => AppTheme.material(true);
  static ThemeData dark() => AppTheme.material(false);
}
