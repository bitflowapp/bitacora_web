import 'package:flutter/material.dart';

import '../colors.dart';
import '../typography.dart';

/// Convenience widget that maps AppTypography styles to a Text widget,
/// automatically inheriting the correct label color from brightness.
class AppText extends StatelessWidget {
  const AppText(this.data,
      {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  // Named constructors for each HIG level
  const AppText.largeTitle(this.data,
      {super.key, this.textAlign, this.maxLines, this.overflow})
      : style = AppTypography.largeTitle;
  const AppText.title1(this.data,
      {super.key, this.textAlign, this.maxLines, this.overflow})
      : style = AppTypography.title1;
  const AppText.title2(this.data,
      {super.key, this.textAlign, this.maxLines, this.overflow})
      : style = AppTypography.title2;
  const AppText.title3(this.data,
      {super.key, this.textAlign, this.maxLines, this.overflow})
      : style = AppTypography.title3;
  const AppText.headline(this.data,
      {super.key, this.textAlign, this.maxLines, this.overflow})
      : style = AppTypography.headline;
  const AppText.body(this.data,
      {super.key, this.textAlign, this.maxLines, this.overflow})
      : style = AppTypography.body;
  const AppText.callout(this.data,
      {super.key, this.textAlign, this.maxLines, this.overflow})
      : style = AppTypography.callout;
  const AppText.subheadline(this.data,
      {super.key, this.textAlign, this.maxLines, this.overflow})
      : style = AppTypography.subheadline;
  const AppText.footnote(this.data,
      {super.key, this.textAlign, this.maxLines, this.overflow})
      : style = AppTypography.footnote;
  const AppText.caption1(this.data,
      {super.key, this.textAlign, this.maxLines, this.overflow})
      : style = AppTypography.caption1;
  const AppText.caption2(this.data,
      {super.key, this.textAlign, this.maxLines, this.overflow})
      : style = AppTypography.caption2;

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final defaultColor = AppColors.label(brightness);
    final resolved =
        (style ?? AppTypography.body).copyWith(color: defaultColor);

    return Text(
      data,
      style: resolved,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Secondary-label variant — uses secondaryLabel color automatically.
class AppSecondaryText extends StatelessWidget {
  const AppSecondaryText(this.data,
      {super.key, this.style, this.textAlign, this.maxLines, this.overflow});

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = AppColors.secondaryLabel(brightness);
    final resolved = (style ?? AppTypography.body).copyWith(color: color);
    return Text(data,
        style: resolved,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow);
  }
}
