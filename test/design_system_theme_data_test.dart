import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_web/design_system/theme_data.dart';
import 'package:bitacora_web/design_system/colors.dart';

void main() {
  group('AppThemeBuilder — light theme', () {
    late ThemeData light;

    setUpAll(() => light = AppThemeBuilder.light());

    test('uses Material 3', () => expect(light.useMaterial3, isTrue));

    test('brightness is light', () {
      expect(light.brightness, Brightness.light);
    });

    test('scaffold background is Apple lightBg (#FFFFFF)', () {
      expect(light.scaffoldBackgroundColor, AppColors.lightBg);
    });

    test('primary color is Apple accentBlue (#007AFF)', () {
      expect(light.colorScheme.primary, AppColors.accentBlue);
    });

    test('no splash / ripple (Apple feel)', () {
      expect(light.splashFactory, NoSplash.splashFactory);
    });

    test('text theme body uses SF Pro Text family', () {
      final body = light.textTheme.bodyMedium;
      expect(body?.fontFamily, '.SF Pro Text');
      expect(body?.fontFamilyFallback, contains('-apple-system'));
    });

    test('divider color matches AppColors.lightDivider', () {
      expect(light.dividerTheme.color, AppColors.lightDivider);
    });

    test('AppBar has zero elevation', () {
      expect(light.appBarTheme.elevation, 0);
      expect(light.appBarTheme.scrolledUnderElevation, 0);
    });

    test('filledButton min height is 44pt (touch target)', () {
      final size = light.filledButtonTheme.style?.minimumSize
          ?.resolve({}) as Size?;
      expect(size?.height, greaterThanOrEqualTo(44));
    });
  });

  group('AppThemeBuilder — dark theme', () {
    late ThemeData dark;

    setUpAll(() => dark = AppThemeBuilder.dark());

    test('brightness is dark', () {
      expect(dark.brightness, Brightness.dark);
    });

    test('scaffold background is OLED black (#000000)', () {
      expect(dark.scaffoldBackgroundColor, AppColors.darkBg);
    });

    test('primary color is Apple accentBlueDark (#0A84FF)', () {
      expect(dark.colorScheme.primary, AppColors.accentBlueDark);
    });

    test('divider color matches AppColors.darkDivider', () {
      expect(dark.dividerTheme.color, AppColors.darkDivider);
    });
  });

  group('AppThemeBuilder — light vs dark differ', () {
    test('scaffold colors differ', () {
      expect(
        AppThemeBuilder.light().scaffoldBackgroundColor,
        isNot(AppThemeBuilder.dark().scaffoldBackgroundColor),
      );
    });

    test('primary colors differ', () {
      expect(
        AppThemeBuilder.light().colorScheme.primary,
        isNot(AppThemeBuilder.dark().colorScheme.primary),
      );
    });
  });
}
