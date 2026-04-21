import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_web/design_system/typography.dart';
import 'package:bitacora_web/design_system/spacing.dart';

void main() {
  group('AppTypography — Apple HIG type scale', () {
    test('largeTitle: 34pt / w700', () {
      expect(AppTypography.largeTitle.fontSize, 34);
      expect(AppTypography.largeTitle.fontWeight, FontWeight.w700);
    });

    test('title1: 28pt / w700', () {
      expect(AppTypography.title1.fontSize, 28);
      expect(AppTypography.title1.fontWeight, FontWeight.w700);
    });

    test('title2: 22pt / w700', () {
      expect(AppTypography.title2.fontSize, 22);
      expect(AppTypography.title2.fontWeight, FontWeight.w700);
    });

    test('title3: 20pt / w600', () {
      expect(AppTypography.title3.fontSize, 20);
      expect(AppTypography.title3.fontWeight, FontWeight.w600);
    });

    test('headline: 17pt / w600', () {
      expect(AppTypography.headline.fontSize, 17);
      expect(AppTypography.headline.fontWeight, FontWeight.w600);
    });

    test('body: 17pt / w400', () {
      expect(AppTypography.body.fontSize, 17);
      expect(AppTypography.body.fontWeight, FontWeight.w400);
    });

    test('callout: 16pt / w400', () {
      expect(AppTypography.callout.fontSize, 16);
      expect(AppTypography.callout.fontWeight, FontWeight.w400);
    });

    test('subheadline: 15pt / w400', () {
      expect(AppTypography.subheadline.fontSize, 15);
      expect(AppTypography.subheadline.fontWeight, FontWeight.w400);
    });

    test('footnote: 13pt / w400', () {
      expect(AppTypography.footnote.fontSize, 13);
      expect(AppTypography.footnote.fontWeight, FontWeight.w400);
    });

    test('caption1: 12pt / w400', () {
      expect(AppTypography.caption1.fontSize, 12);
      expect(AppTypography.caption1.fontWeight, FontWeight.w400);
    });

    test('caption2: 11pt / w400 (smallest)', () {
      expect(AppTypography.caption2.fontSize, 11);
      expect(AppTypography.caption2.fontWeight, FontWeight.w400);
    });

    test('scale is strictly descending in font size', () {
      final sizes = [
        AppTypography.largeTitle.fontSize!,
        AppTypography.title1.fontSize!,
        AppTypography.title2.fontSize!,
        AppTypography.title3.fontSize!,
        AppTypography.headline.fontSize!,
        AppTypography.callout.fontSize!,
        AppTypography.subheadline.fontSize!,
        AppTypography.footnote.fontSize!,
        AppTypography.caption1.fontSize!,
        AppTypography.caption2.fontSize!,
      ];
      for (var i = 0; i < sizes.length - 1; i++) {
        expect(sizes[i], greaterThan(sizes[i + 1]),
            reason: 'index $i (${sizes[i]}) should be > index ${i + 1} (${sizes[i + 1]})');
      }
    });

    test('all styles use SF Pro Text family', () {
      final styles = [
        AppTypography.largeTitle,
        AppTypography.title1,
        AppTypography.title2,
        AppTypography.title3,
        AppTypography.headline,
        AppTypography.body,
        AppTypography.callout,
        AppTypography.subheadline,
        AppTypography.footnote,
        AppTypography.caption1,
        AppTypography.caption2,
      ];
      for (final s in styles) {
        expect(s.fontFamily, '.SF Pro Text');
        expect(s.fontFamilyFallback, contains('-apple-system'));
      }
    });
  });

  group('AppSpacing — 4pt grid', () {
    test('base scale values', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 12);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.xl, 24);
      expect(AppSpacing.xxl, 32);
      expect(AppSpacing.xxxl, 48);
    });

    test('all scale values are multiples of 4', () {
      for (final v in [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
      ]) {
        expect(v % 4, 0, reason: '$v is not a multiple of 4');
      }
    });

    test('touchTarget meets Apple HIG minimum (44pt)', () {
      expect(AppSpacing.touchTarget, greaterThanOrEqualTo(44));
    });

    test('pagePadding horizontal is lg (16)', () {
      expect(AppSpacing.pagePadding.left, AppSpacing.lg);
      expect(AppSpacing.pagePadding.right, AppSpacing.lg);
    });

    test('gap SizedBox dimensions match scale', () {
      expect(AppSpacing.gapSm.width, AppSpacing.sm);
      expect(AppSpacing.gapLg.height, AppSpacing.lg);
    });
  });
}
