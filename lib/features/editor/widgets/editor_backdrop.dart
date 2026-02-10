part of '../editor_screen.dart';

class _WarmBackdrop extends StatelessWidget {
  const _WarmBackdrop({required this.palette});
  final _SheetPalette palette;

  @override
  Widget build(BuildContext context) {
    final topTone = palette.headerBg;
    final bottomTone = palette.gridBg;

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.7),
            radius: 1.2,
            colors: [
              topTone.withOpacity(palette.isLight ? 0.34 : 0.42),
              Colors.transparent,
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0.8, 0.6),
              radius: 1.3,
              colors: [
                bottomTone.withOpacity(palette.isLight ? 0.30 : 0.38),
                Colors.transparent,
              ],
              stops: const [0.0, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // sin glow Android
  }
}

// ============================== Helpers ====================================

// Compat simple: evita warning de "unawaited" sin depender de SDK.
void unawaited(Future<void>? f) {}
