// lib/widgets/glass_appbar.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class GlassAppBarBackground extends StatelessWidget {
  const GlassAppBarBackground({
    super.key,
    required this.isLight,
  });

  final bool isLight;

  @override
  Widget build(BuildContext context) {
    final Color base =
        isLight ? Colors.white : const Color(0xFF020617); // dark azul/gris
    final Color border =
        isLight ? const Color(0x33000000) : const Color(0x33FFFFFF);

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: 12,
          sigmaY: 12,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLight
                  ? [
                      base.withValues(alpha: 0.80),
                      base.withValues(alpha: 0.94),
                    ]
                  : [
                      base.withValues(alpha: 0.78),
                      base.withValues(alpha: 0.94),
                    ],
            ),
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 0.7,
              color: border,
            ),
          ),
        ),
      ),
    );
  }
}
