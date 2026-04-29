import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Canonical Apple-quality ThemeData for Bit Flow.
///
/// Both light and dark variants are built from AppColors + AppTypography so
/// the design system is the single source of truth.
abstract final class AppThemeBuilder {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    // ── Semantic tokens ──────────────────────────────────────────────────────
    final bg = isLight ? AppColors.lightBg : AppColors.darkBg;
    final surface =
        isLight ? AppColors.lightSecondaryBg : AppColors.darkSecondaryBg;
    // Slightly elevated surface for dialogs, popups, bottom sheets — gives
    // the premium B2B "card on canvas" depth without heavy shadows.
    final surfaceElevated =
        isLight ? AppColors.lightBg : AppColors.darkTertiaryBg;
    final surfaceFloating =
        isLight ? AppColors.lightBg : AppColors.darkElevatedBg;
    final label = isLight ? AppColors.lightLabel : AppColors.darkLabel;
    final secondaryLabel = isLight
        ? AppColors.lightSecondaryLabel.withValues(alpha: 0.6)
        : AppColors.darkSecondaryLabel;
    final divider = isLight ? AppColors.lightDivider : AppColors.darkDivider;
    final fill = isLight ? AppColors.lightFill : AppColors.darkFill;
    final accent = isLight ? AppColors.accentBlue : AppColors.accentBlueDark;
    final accentSoft =
        isLight ? AppColors.accentBlueSoft : AppColors.accentBlueSoftDark;

    // ── Text theme from AppTypography ────────────────────────────────────────
    final textTheme = TextTheme(
      displayLarge: AppTypography.largeTitle.copyWith(color: label),
      displayMedium: AppTypography.title1.copyWith(color: label),
      displaySmall: AppTypography.title2.copyWith(color: label),
      headlineLarge: AppTypography.title3.copyWith(color: label),
      headlineMedium: AppTypography.headline.copyWith(color: label),
      headlineSmall: AppTypography.body.copyWith(color: label),
      titleLarge: AppTypography.headline.copyWith(color: label),
      titleMedium: AppTypography.body.copyWith(color: label),
      titleSmall: AppTypography.callout.copyWith(color: label),
      bodyLarge: AppTypography.body.copyWith(color: label),
      bodyMedium: AppTypography.callout.copyWith(color: label),
      bodySmall: AppTypography.subheadline.copyWith(color: secondaryLabel),
      labelLarge: AppTypography.headline.copyWith(color: label),
      labelMedium: AppTypography.footnote.copyWith(color: secondaryLabel),
      labelSmall: AppTypography.caption2.copyWith(color: secondaryLabel),
    );

    // ── ColorScheme ─────────────────────────────────────────────────────────
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      primaryContainer: accent.withValues(alpha: 0.15),
      onPrimaryContainer: accent,
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: surface,
      onSecondaryContainer: label,
      tertiary: isLight ? AppColors.accentGreen : AppColors.accentGreenDark,
      onTertiary: Colors.white,
      tertiaryContainer:
          (isLight ? AppColors.accentGreen : AppColors.accentGreenDark)
              .withValues(alpha: 0.15),
      onTertiaryContainer:
          isLight ? AppColors.accentGreen : AppColors.accentGreenDark,
      error: isLight ? AppColors.accentRed : AppColors.accentRedDark,
      onError: Colors.white,
      errorContainer: (isLight ? AppColors.accentRed : AppColors.accentRedDark)
          .withValues(alpha: 0.12),
      onErrorContainer: isLight ? AppColors.accentRed : AppColors.accentRedDark,
      surface: bg,
      onSurface: label,
      surfaceContainerLowest: bg,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceElevated,
      surfaceContainerHighest: surfaceFloating,
      onSurfaceVariant: secondaryLabel,
      outline: divider,
      outlineVariant: isLight
          ? AppColors.lightOpaqueSeparator
          : AppColors.darkOpaqueSeparator,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface:
          isLight ? AppColors.darkSecondaryBg : AppColors.lightSecondaryBg,
      onInverseSurface: isLight ? AppColors.darkLabel : AppColors.lightLabel,
      inversePrimary: isLight ? AppColors.accentBlueDark : AppColors.accentBlue,
    );

    // ── Overlay colors ───────────────────────────────────────────────────────
    final overlayPressed = (isLight ? Colors.black : Colors.white)
        .withValues(alpha: isLight ? 0.06 : 0.08);
    final overlayHover = (isLight ? Colors.black : Colors.white)
        .withValues(alpha: isLight ? 0.035 : 0.05);

    const pageTransitions = PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.fuchsia: CupertinoPageTransitionsBuilder(),
      },
    );

    const pillShape = StadiumBorder();

    final inputFill = fill.withValues(alpha: 0.6);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      cardColor: surface,
      dividerColor: divider,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      pageTransitionsTheme: pageTransitions,
      fontFamily: '.SF Pro Text',
      fontFamilyFallback: const [
        '-apple-system',
        'BlinkMacSystemFont',
        'Segoe UI',
        'Roboto',
        'sans-serif',
      ],
      textTheme: textTheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: accent.withValues(alpha: 0.20),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accent,
        selectionColor: accent.withValues(alpha: isLight ? 0.20 : 0.24),
        selectionHandleColor: accent,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: bg.withValues(alpha: isLight ? 0.90 : 0.93),
        surfaceTintColor: Colors.transparent,
        foregroundColor: label,
        titleTextStyle: AppTypography.headline.copyWith(color: label),
        iconTheme: IconThemeData(color: label, size: 22),
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.all(AppSpacing.sm),
        elevation: isLight ? 0 : 0,
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          side: BorderSide(
            color: divider.withValues(alpha: isLight ? 0.75 : 0.55),
            width: 0.5,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: isLight ? 0 : 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.xl),
          side: BorderSide(
            color: divider.withValues(alpha: isLight ? 0.80 : 0.50),
            width: 0.5,
          ),
        ),
        titleTextStyle: AppTypography.headline.copyWith(color: label),
        contentTextStyle: AppTypography.body.copyWith(color: secondaryLabel),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        hintStyle: AppTypography.body.copyWith(color: secondaryLabel),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          borderSide: BorderSide(
            color: divider.withValues(alpha: isLight ? 0.80 : 0.55),
            width: 0.9,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          borderSide: BorderSide(
            color: divider.withValues(alpha: isLight ? 0.80 : 0.55),
            width: 0.9,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(accent),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          shape: const WidgetStatePropertyAll(pillShape),
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 11),
          ),
          textStyle: WidgetStatePropertyAll(
            AppTypography.headline,
          ),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayPressed;
            if (states.contains(WidgetState.hovered)) return overlayHover;
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(pillShape),
          side: WidgetStatePropertyAll(
            BorderSide(color: accent.withValues(alpha: 0.6)),
          ),
          foregroundColor: WidgetStatePropertyAll(accent),
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 11),
          ),
          textStyle: WidgetStatePropertyAll(AppTypography.headline),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayPressed;
            if (states.contains(WidgetState.hovered)) return overlayHover;
            return null;
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(pillShape),
          foregroundColor: WidgetStatePropertyAll(accent),
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 11),
          ),
          textStyle: WidgetStatePropertyAll(AppTypography.headline),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayPressed;
            if (states.contains(WidgetState.hovered)) return overlayHover;
            return null;
          }),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(CircleBorder()),
          minimumSize: const WidgetStatePropertyAll(
            Size(AppSpacing.touchTarget, AppSpacing.touchTarget),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.sm)),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return overlayPressed;
            if (states.contains(WidgetState.hovered)) return overlayHover;
            return null;
          }),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return isLight ? AppColors.lightFill : AppColors.darkFill;
        }),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackOutlineWidth: const WidgetStatePropertyAll(0),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(
          color: divider.withValues(alpha: isLight ? 0.80 : 0.58),
        ),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
      ),
      chipTheme: ChipThemeData(
        shape: pillShape,
        side:
            BorderSide(color: divider.withValues(alpha: isLight ? 0.78 : 0.55)),
        backgroundColor: fill.withValues(alpha: 0.6),
        selectedColor: accentSoft,
        labelStyle: AppTypography.footnote.copyWith(color: label),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: isLight ? 4 : 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          side: BorderSide(
            color: divider.withValues(alpha: isLight ? 0.78 : 0.55),
            width: 0.5,
          ),
        ),
        textStyle: AppTypography.body.copyWith(color: label),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color:
              (isLight ? Colors.black : Colors.white).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
        textStyle: AppTypography.caption1.copyWith(
          color: isLight ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            (isLight ? Colors.black : Colors.white).withValues(alpha: 0.90),
        contentTextStyle: AppTypography.body.copyWith(
          color: isLight ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surfaceElevated,
        modalElevation: isLight ? 0 : 6,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.xl),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: secondaryLabel,
        textColor: label,
        dense: true,
        minVerticalPadding: AppSpacing.sm,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: fill,
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(AppSpacing.xs),
        thickness: const WidgetStatePropertyAll(6),
        thumbVisibility: const WidgetStatePropertyAll(true),
        thumbColor: WidgetStatePropertyAll(
          secondaryLabel.withValues(alpha: 0.4),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 0.5,
        space: 1,
      ),
    );
  }
}
