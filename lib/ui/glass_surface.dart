import 'dart:ui';

import 'package:flutter/material.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.radius = 20,
    this.blurSigma = 14,
    this.backgroundColor = const Color(0xCCFFFFFF),
    this.borderColor = const Color(0x30FFFFFF),
    this.shadowColor = const Color(0x14000000),
    this.shadowBlur = 16,
    this.shadowOffset = const Offset(0, 8),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final double blurSigma;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final double shadowBlur;
  final Offset shadowOffset;

  @override
  Widget build(BuildContext context) {
    final surface = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: shadowBlur,
            offset: shadowOffset,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor, width: 0.7),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );

    if (margin == null) return surface;
    return Padding(padding: margin!, child: surface);
  }
}
