import 'package:flutter/material.dart';

abstract final class AppTypography {
  // System font: iOS/macOS uses SF Pro; Android/Web fall back gracefully.
  static const String _family = '.SF Pro Text';
  static const List<String> _fallback = [
    '-apple-system',
    'BlinkMacSystemFont',
    'Segoe UI',
    'Roboto',
    'sans-serif',
  ];

  // ── Apple HIG type scale ──────────────────────────────────────────────────

  /// Large Title — 34 pt / Bold. Screen-level headings (e.g. "Planillas").
  static const TextStyle largeTitle = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.36,
  );

  /// Title 1 — 28 pt / Bold. Major section titles.
  static const TextStyle title1 = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.21,
    letterSpacing: 0.36,
  );

  /// Title 2 — 22 pt / Bold. Card titles, dialog headings.
  static const TextStyle title2 = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.27,
    letterSpacing: 0.36,
  );

  /// Title 3 — 20 pt / Semibold. Subtitles, section headers in lists.
  static const TextStyle title3 = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.30,
  );

  /// Headline — 17 pt / Semibold. List row titles, action labels.
  static const TextStyle headline = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// Body — 17 pt / Regular. Default paragraph text.
  static const TextStyle body = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.41,
  );

  /// Callout — 16 pt / Regular. Slightly smaller body (descriptions, tags).
  static const TextStyle callout = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.375,
  );

  /// Subheadline — 15 pt / Regular. Supporting detail below headlines.
  static const TextStyle subheadline = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Footnote — 13 pt / Regular. Supplemental information.
  static const TextStyle footnote = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.385,
    letterSpacing: 0.07,
  );

  /// Caption 1 — 12 pt / Regular. Timestamps, metadata labels.
  static const TextStyle caption1 = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.417,
    letterSpacing: 0,
  );

  /// Caption 2 — 11 pt / Regular. Smallest visible text (badges, overflows).
  static const TextStyle caption2 = TextStyle(
    fontFamily: _family,
    fontFamilyFallback: _fallback,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.364,
    letterSpacing: 0.06,
  );
}
