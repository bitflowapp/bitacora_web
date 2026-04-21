import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Background ────────────────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSecondaryBg = Color(0xFFF5F5F7);
  static const Color lightTertiaryBg = Color(0xFFEFEFF4);

  static const Color darkBg = Color(0xFF000000); // OLED true black
  static const Color darkSecondaryBg = Color(0xFF1C1C1E);
  static const Color darkTertiaryBg = Color(0xFF2C2C2E);

  // ── Labels (text) ─────────────────────────────────────────────────────────
  static const Color lightLabel = Color(0xFF000000);
  static const Color lightSecondaryLabel = Color(0xFF3C3C43); // use @ 60% α
  static const Color lightTertiaryLabel = Color(0xFF3C3C43); // use @ 30% α
  static const Color lightQuaternaryLabel = Color(0xFF3C3C43); // use @ 18% α

  static const Color darkLabel = Color(0xFFFFFFFF);
  static const Color darkSecondaryLabel = Color(0xFF8E8E93); // composited value
  static const Color darkTertiaryLabel = Color(0xFF48484A);
  static const Color darkQuaternaryLabel = Color(0xFF3A3A3C);

  // ── Fills (backgrounds for interactive elements) ──────────────────────────
  static const Color lightFill = Color(0xFFE9E9EB); // systemFill light
  static const Color lightSecondaryFill = Color(0xFFEEEEF0);
  static const Color darkFill = Color(0xFF38383A); // systemFill dark
  static const Color darkSecondaryFill = Color(0xFF2C2C2E);

  // ── Separators / Dividers ─────────────────────────────────────────────────
  static const Color lightDivider = Color(0xFFE5E5EA); // separator
  static const Color lightOpaqueSeparator = Color(0xFFC6C6C8);
  static const Color darkDivider = Color(0xFF38383A); // separator dark
  static const Color darkOpaqueSeparator = Color(0xFF48484A);

  // ── Accent colors (Apple system palette) ─────────────────────────────────
  /// systemBlue — light mode (#007AFF), dark mode (#0A84FF)
  static const Color accentBlue = Color(0xFF007AFF);
  static const Color accentBlueDark = Color(0xFF0A84FF);

  static const Color accentGreen = Color(0xFF34C759);
  static const Color accentGreenDark = Color(0xFF30D158);

  static const Color accentRed = Color(0xFFFF3B30);
  static const Color accentRedDark = Color(0xFFFF453A);

  static const Color accentOrange = Color(0xFFFF9500);
  static const Color accentOrangeDark = Color(0xFFFF9F0A);

  static const Color accentYellow = Color(0xFFFFCC00);
  static const Color accentYellowDark = Color(0xFFFFD60A);

  // ── Semantic helpers ──────────────────────────────────────────────────────
  static Color bg(Brightness b) =>
      b == Brightness.light ? lightBg : darkBg;

  static Color secondaryBg(Brightness b) =>
      b == Brightness.light ? lightSecondaryBg : darkSecondaryBg;

  static Color label(Brightness b) =>
      b == Brightness.light ? lightLabel : darkLabel;

  static Color secondaryLabel(Brightness b) =>
      b == Brightness.light
          ? lightSecondaryLabel.withValues(alpha: 0.6)
          : darkSecondaryLabel;

  static Color divider(Brightness b) =>
      b == Brightness.light ? lightDivider : darkDivider;

  static Color accent(Brightness b) =>
      b == Brightness.light ? accentBlue : accentBlueDark;

  static Color fill(Brightness b) =>
      b == Brightness.light ? lightFill : darkFill;
}
