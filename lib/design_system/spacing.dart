import 'package:flutter/material.dart';

abstract final class AppSpacing {
  // ── 4-pt base grid ───────────────────────────────────────────────────────
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  // ── Apple HIG minimum touch target ───────────────────────────────────────
  static const double touchTarget = 44;

  // ── Common EdgeInsets shortcuts ───────────────────────────────────────────
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: xl);

  static const EdgeInsets cardPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

  static const EdgeInsets listTilePadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: sm);

  // ── SizedBox helpers ──────────────────────────────────────────────────────
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapSm = SizedBox(width: sm, height: sm);
  static const SizedBox gapMd = SizedBox(width: md, height: md);
  static const SizedBox gapLg = SizedBox(width: lg, height: lg);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);
}
