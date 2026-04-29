import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Background ────────────────────────────────────────────────────────────
  // Light keeps Apple's clean canvas.
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSecondaryBg = Color(0xFFF5F5F7);
  static const Color lightTertiaryBg = Color(0xFFEFEFF4);

  // Dark uses Bit Flow's premium B2B canvas: a cool-graphite black that's
  // softer than OLED true black, with three elevation layers for cards and
  // overlays (deep → card → elevated card).
  static const Color darkBg = Color(0xFF0B0D10);
  static const Color darkSecondaryBg = Color(0xFF14171C);
  static const Color darkTertiaryBg = Color(0xFF1B2027);
  static const Color darkElevatedBg = Color(0xFF20262E);

  // ── Labels (text) ─────────────────────────────────────────────────────────
  static const Color lightLabel = Color(0xFF000000);
  static const Color lightSecondaryLabel = Color(0xFF3C3C43); // use @ 60% α
  static const Color lightTertiaryLabel = Color(0xFF3C3C43); // use @ 30% α
  static const Color lightQuaternaryLabel = Color(0xFF3C3C43); // use @ 18% α

  static const Color darkLabel = Color(0xFFF2F4F7);
  static const Color darkSecondaryLabel = Color(0xFFA8B0BB);
  static const Color darkTertiaryLabel = Color(0xFF6B7380);
  static const Color darkQuaternaryLabel = Color(0xFF3F454F);

  // ── Fills (backgrounds for interactive elements) ──────────────────────────
  static const Color lightFill = Color(0xFFE9E9EB); // systemFill light
  static const Color lightSecondaryFill = Color(0xFFEEEEF0);
  static const Color darkFill = Color(0xFF252B33);
  static const Color darkSecondaryFill = Color(0xFF1B2027);

  // ── Separators / Dividers ─────────────────────────────────────────────────
  static const Color lightDivider = Color(0xFFE5E5EA); // separator
  static const Color lightOpaqueSeparator = Color(0xFFC6C6C8);
  static const Color darkDivider = Color(0xFF252B33);
  static const Color darkOpaqueSeparator = Color(0xFF323943);

  // ── Accent colors ─────────────────────────────────────────────────────────
  /// Bit Flow B2B blue — the premium accent. Light / dark variants are tuned
  /// for contrast on each canvas. We keep `accentBlue*` aliases to preserve
  /// the existing API while giving the dark variant the slightly cooler,
  /// more saturated tone the redesign calls for.
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color accentBlueDark = Color(0xFF3A82F7);

  /// Soft tinted backgrounds for accent chips / hover states.
  static const Color accentBlueSoft = Color(0xFFE8EFFC);
  static const Color accentBlueSoftDark = Color(0xFF1A2742);

  static const Color accentGreen = Color(0xFF34C759);
  static const Color accentGreenDark = Color(0xFF30D158);

  static const Color accentRed = Color(0xFFFF3B30);
  static const Color accentRedDark = Color(0xFFFF453A);

  static const Color accentOrange = Color(0xFFFF9500);
  static const Color accentOrangeDark = Color(0xFFFF9F0A);

  static const Color accentYellow = Color(0xFFFFCC00);
  static const Color accentYellowDark = Color(0xFFFFD60A);

  // ── Semantic helpers ──────────────────────────────────────────────────────
  static Color bg(Brightness b) => b == Brightness.light ? lightBg : darkBg;

  static Color secondaryBg(Brightness b) =>
      b == Brightness.light ? lightSecondaryBg : darkSecondaryBg;

  static Color tertiaryBg(Brightness b) =>
      b == Brightness.light ? lightTertiaryBg : darkTertiaryBg;

  static Color elevatedBg(Brightness b) =>
      b == Brightness.light ? lightBg : darkElevatedBg;

  static Color label(Brightness b) =>
      b == Brightness.light ? lightLabel : darkLabel;

  static Color secondaryLabel(Brightness b) => b == Brightness.light
      ? lightSecondaryLabel.withValues(alpha: 0.6)
      : darkSecondaryLabel;

  static Color tertiaryLabel(Brightness b) => b == Brightness.light
      ? lightSecondaryLabel.withValues(alpha: 0.30)
      : darkTertiaryLabel;

  static Color divider(Brightness b) =>
      b == Brightness.light ? lightDivider : darkDivider;

  static Color accent(Brightness b) =>
      b == Brightness.light ? accentBlue : accentBlueDark;

  static Color accentSoft(Brightness b) =>
      b == Brightness.light ? accentBlueSoft : accentBlueSoftDark;

  static Color fill(Brightness b) =>
      b == Brightness.light ? lightFill : darkFill;
}
