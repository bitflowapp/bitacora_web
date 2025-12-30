// lib/widgets/floating_icons_layer.dart
// Capa global con íconos flotando "estilo iOS": vidrio translúcido + blur.
// - Liviano: 1 AnimationController para todo.
// - No interfiere con UI: IgnorePointer(true).
// - Soporta claro/oscuro automáticamente.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FloatingIconsLayer extends StatefulWidget {
  const FloatingIconsLayer({
    super.key,
    required this.isLight,
    required this.seed,
    this.intensity = 1.0, // 0.0 a 1.0 para regular lo “animada” que está
  });

  final bool isLight;
  final Color seed;
  final double intensity;

  @override
  State<FloatingIconsLayer> createState() => _FloatingIconsLayerState();
}

class _FloatingIconsLayerState extends State<FloatingIconsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Config de íconos (posiciones relativas [0..1], tamaño, amplitud, fase).
  // Elegí íconos "muy iOS".
  final List<_IconSpec> _icons = <_IconSpec>[
    _IconSpec(CupertinoIcons.square_grid_2x2, 0.15, 0.20, 34, 24, 0.0),
    _IconSpec(CupertinoIcons.rectangle_on_rectangle, 0.82, 0.22, 36, 20, 0.8),
    _IconSpec(CupertinoIcons.bolt_horizontal_circle, 0.70, 0.72, 40, 22, 1.4),
    _IconSpec(CupertinoIcons.doc_text, 0.28, 0.68, 34, 18, 0.6),
    _IconSpec(CupertinoIcons.location_solid, 0.50, 0.35, 30, 16, 1.0),
    _IconSpec(CupertinoIcons.cloud_moon_fill, 0.08, 0.80, 44, 26, 1.8),
    _IconSpec(CupertinoIcons.wifi, 0.90, 0.58, 30, 16, 2.4),
    _IconSpec(CupertinoIcons.chart_bar_square, 0.42, 0.88, 36, 20, 3.1),
  ];

  @override
  void initState() {
    super.initState();
    // Velocidad base: 22s. Regulamos por intensidad.
    final durMs = (22000 / widget.intensity.clamp(0.25, 1.0)).round();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durMs),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant FloatingIconsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intensity != widget.intensity) {
      final durMs = (22000 / widget.intensity.clamp(0.25, 1.0)).round();
      _ctrl.duration = Duration(milliseconds: durMs);
      if (!_ctrl.isAnimating) _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final light = widget.isLight;
    final glassColor =
        light ? Colors.white.withOpacity(0.10) : Colors.black.withOpacity(0.18);
    final borderColor =
        light ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.10);
    final glow = widget.seed.withOpacity(light ? 0.20 : 0.25);

    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth;
                final h = box.maxHeight;
                final t = _ctrl.value * 2 * math.pi;

                return Stack(
                  children: [
                    for (final spec in _icons)
                      _buildIcon(
                        spec: spec,
                        w: w,
                        h: h,
                        t: t,
                        glassColor: glassColor,
                        borderColor: borderColor,
                        glow: glow,
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildIcon({
    required _IconSpec spec,
    required double w,
    required double h,
    required double t,
    required Color glassColor,
    required Color borderColor,
    required Color glow,
  }) {
    // Trayectoria suave estilo iOS (lissajous simple).
    final dx = math.sin(t + spec.phase) * spec.amp;
    final dy = math.cos(t * 0.8 + spec.phase) * (spec.amp * 0.8);

    final x = (spec.x * w + dx).clamp(0.0, w - spec.size);
    final y = (spec.y * h + dy).clamp(0.0, h - spec.size);

    return Positioned(
      left: x,
      top: y,
      child: _GlassIcon(
        icon: spec.icon,
        size: spec.size,
        glassColor: glassColor,
        borderColor: borderColor,
        glow: glow,
      ),
    );
  }
}

class _IconSpec {
  const _IconSpec(this.icon, this.x, this.y, this.size, this.amp, this.phase);
  final IconData icon;
  final double x, y; // pos relativa [0..1]
  final double size; // px
  final double amp; // amplitud px
  final double phase; // fase rad
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({
    required this.icon,
    required this.size,
    required this.glassColor,
    required this.borderColor,
    required this.glow,
  });

  final IconData icon;
  final double size;
  final Color glassColor;
  final Color borderColor;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.38;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            blurRadius: size * 0.35,
            spreadRadius: size * 0.02,
            color: glow,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: borderColor, width: 1),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: size * 0.54,
              color: Colors.white.withOpacity(0.90),
            ),
          ),
        ),
      ),
    );
  }
}
