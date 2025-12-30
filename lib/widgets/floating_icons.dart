import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class FloatingIconsLayer extends StatelessWidget {
  const FloatingIconsLayer({super.key});
  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final base = isLight ? Colors.black : Colors.white;
    final bubble = base.withValues(alpha: 0.06);
    const items =
        <({Alignment align, IconData icon, double size, int delayMs})>[
      (
        align: Alignment(-0.9, -0.8),
        icon: Icons.grid_view_rounded,
        size: 42,
        delayMs: 0
      ),
      (
        align: Alignment(0.85, -0.7),
        icon: Icons.table_chart_rounded,
        size: 50,
        delayMs: 200
      ),
      (
        align: Alignment(-0.75, 0.15),
        icon: Icons.description_outlined,
        size: 38,
        delayMs: 400
      ),
      (
        align: Alignment(0.75, 0.3),
        icon: Icons.send_rounded,
        size: 40,
        delayMs: 600
      ),
      (
        align: Alignment(-0.2, -0.05),
        icon: Icons.bolt_rounded,
        size: 36,
        delayMs: 800
      ),
      (
        align: Alignment(0.1, 0.85),
        icon: Icons.place_rounded,
        size: 44,
        delayMs: 1000
      ),
      (
        align: Alignment(-0.95, 0.8),
        icon: Icons.settings,
        size: 40,
        delayMs: 1200
      ),
    ];
    return IgnorePointer(
      ignoring: true,
      child: RepaintBoundary(
        child: Stack(
          children: [
            for (final it in items)
              Align(
                alignment: it.align,
                child: Container(
                  decoration:
                      BoxDecoration(color: bubble, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(10),
                  child: Icon(it.icon,
                      size: it.size,
                      color: Colors.white.withValues(alpha: 0.8)),
                )
                    .animate(
                        delay: Duration(milliseconds: it.delayMs),
                        onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(duration: 900.ms, curve: Curves.easeOut)
                    .moveY(
                        begin: 6,
                        end: -6,
                        duration: 3600.ms,
                        curve: Curves.easeInOut)
                    .then(delay: 0.ms)
                    .moveX(
                        begin: -4,
                        end: 4,
                        duration: 4200.ms,
                        curve: Curves.easeInOut),
              ),
          ],
        ),
      ),
    );
  }
}
