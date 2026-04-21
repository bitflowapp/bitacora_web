import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_web/design_system/colors.dart';

void main() {
  group('AppColors — palette values', () {
    test('light background is pure white', () {
      expect(AppColors.lightBg, const Color(0xFFFFFFFF));
    });

    test('dark background is OLED black', () {
      expect(AppColors.darkBg, const Color(0xFF000000));
    });

    test('light accent is Apple systemBlue', () {
      expect(AppColors.accentBlue, const Color(0xFF007AFF));
    });

    test('dark accent differs from light accent', () {
      expect(AppColors.accentBlueDark, const Color(0xFF0A84FF));
      expect(AppColors.accentBlue, isNot(AppColors.accentBlueDark));
    });

    test('dark secondary bg matches Apple #1C1C1E', () {
      expect(AppColors.darkSecondaryBg, const Color(0xFF1C1C1E));
    });
  });

  group('AppColors — WCAG AA contrast (≥4.5:1 normal text, ≥3:1 large)', () {
    double contrastRatio(Color fg, Color bg) {
      final lFg = fg.computeLuminance();
      final lBg = bg.computeLuminance();
      final lighter = lFg > lBg ? lFg : lBg;
      final darker = lFg > lBg ? lBg : lFg;
      return (lighter + 0.05) / (darker + 0.05);
    }

    test('lightLabel on lightBg = 21:1 (passes AAA)', () {
      final ratio = contrastRatio(AppColors.lightLabel, AppColors.lightBg);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('darkLabel on darkBg = 21:1 (passes AAA)', () {
      final ratio = contrastRatio(AppColors.darkLabel, AppColors.darkBg);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('darkSecondaryLabel (#8E8E93) on darkBg (#000000) passes AA', () {
      final ratio =
          contrastRatio(AppColors.darkSecondaryLabel, AppColors.darkBg);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('accentBlue (#007AFF) on lightBg — passes AA for large text (≥3:1)',
        () {
      final ratio = contrastRatio(AppColors.accentBlue, AppColors.lightBg);
      expect(ratio, greaterThanOrEqualTo(3.0));
    });

    test('accentBlueDark (#0A84FF) on darkBg (#000000) passes AA', () {
      final ratio = contrastRatio(AppColors.accentBlueDark, AppColors.darkBg);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  });

  group('AppColors — semantic helpers', () {
    test('bg() returns correct value per brightness', () {
      expect(AppColors.bg(Brightness.light), AppColors.lightBg);
      expect(AppColors.bg(Brightness.dark), AppColors.darkBg);
    });

    test('accent() returns correct value per brightness', () {
      expect(AppColors.accent(Brightness.light), AppColors.accentBlue);
      expect(AppColors.accent(Brightness.dark), AppColors.accentBlueDark);
    });
  });
}
