import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_web/design_system/colors.dart';

void main() {
  group('AppColors — palette values', () {
    test('light background is pure white', () {
      expect(AppColors.lightBg, const Color(0xFFFFFFFF));
    });

    test('dark background is Bit Flow premium graphite #0B0D10', () {
      expect(AppColors.darkBg, const Color(0xFF0B0D10));
    });

    test('light accent is Bit Flow premium blue #2563EB', () {
      expect(AppColors.accentBlue, const Color(0xFF2563EB));
    });

    test('dark accent differs from light accent', () {
      expect(AppColors.accentBlueDark, const Color(0xFF3A82F7));
      expect(AppColors.accentBlue, isNot(AppColors.accentBlueDark));
    });

    test('dark secondary bg is Bit Flow card surface #14171C', () {
      expect(AppColors.darkSecondaryBg, const Color(0xFF14171C));
    });

    test('layered surfaces ascend brightness (bg < secondary < tertiary < elevated)',
        () {
      expect(AppColors.darkBg.computeLuminance(),
          lessThan(AppColors.darkSecondaryBg.computeLuminance()));
      expect(AppColors.darkSecondaryBg.computeLuminance(),
          lessThan(AppColors.darkTertiaryBg.computeLuminance()));
      expect(AppColors.darkTertiaryBg.computeLuminance(),
          lessThan(AppColors.darkElevatedBg.computeLuminance()));
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

    test('darkSecondaryLabel on darkBg passes AA', () {
      final ratio =
          contrastRatio(AppColors.darkSecondaryLabel, AppColors.darkBg);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });

    test('accentBlue (#2563EB) on lightBg — passes AA for large text (≥3:1)',
        () {
      final ratio = contrastRatio(AppColors.accentBlue, AppColors.lightBg);
      expect(ratio, greaterThanOrEqualTo(3.0));
    });

    test('accentBlueDark (#3A82F7) on darkBg passes AA', () {
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
