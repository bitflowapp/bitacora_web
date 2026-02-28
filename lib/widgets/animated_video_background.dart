// lib/widgets/animated_video_background.dart
//
// AnimatedVideoBackground — fondo seguro para Web (NO bloquea el UI).
//
// Problema típico: backgrounds con video/asset (o blur pesado) que quedan “cargando” infinito
// en Chrome (sobre todo con service worker / cache / codecs). Solución: fondo 100% Flutter
// con gradientes animados que SIEMPRE renderiza el child.
//
// Sin dependencias externas. Funciona en Web/Windows/Android/iOS.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedVideoBackground extends StatefulWidget {
  const AnimatedVideoBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AnimatedVideoBackground> createState() =>
      _AnimatedVideoBackgroundState();
}

class _AnimatedVideoBackgroundState extends State<AnimatedVideoBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Paleta “premium” y discreta. Evita negro plano para no “aplastar” el UI.
    final Color base0 =
        isDark ? const Color(0xFF040611) : const Color(0xFFF5F5FA);
    final Color base1 =
        isDark ? const Color(0xFF070A1F) : const Color(0xFFFFFFFF);

    // El acento se “respeta” pero en opacidades bajas para no ensuciar.
    final Color accent = theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value; // 0..1

        // Movimiento suave de “luces”.
        final dx = math.sin(t * math.pi * 2) * 0.35;
        final dy = math.cos(t * math.pi * 2) * 0.25;
        final centerA = Alignment(dx, dy);
        final centerB = Alignment(-dx * 0.85, -dy * 0.9);

        final glowA = accent.withValues(alpha: isDark ? 0.18 : 0.10); // luz principal
        final glowB = Color.lerp(accent, Colors.white, 0.35)!
            .withValues(alpha: isDark ? 0.10 : 0.06); // luz secundaria

        return Stack(
          fit: StackFit.expand,
          children: [
            // Fondo base
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [base0, base1],
                ),
              ),
            ),

            // Luz radial 1
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: centerA,
                    radius: 1.25,
                    colors: [glowA, Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // Luz radial 2
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: centerB,
                    radius: 1.35,
                    colors: [glowB, Colors.transparent],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),

            // Contenido
            widget.child,
          ],
        );
      },
    );
  }
}
