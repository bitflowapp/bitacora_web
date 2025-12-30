import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Envuelve una pantalla para que:
/// - Toda la vista sea desplazable
/// - Tenga rebote estilo iOS en Web/Safari
/// - El scroll sea fácil de “agarrar” desde cualquier punto vertical
class IosFullPageScroll extends StatelessWidget {
  final Widget child;

  const IosFullPageScroll({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _NoGlowIosScrollBehavior(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            // Rebote tipo iOS dentro de Flutter
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            dragStartBehavior: DragStartBehavior.start,
            child: ConstrainedBox(
              // Para que el contenido pueda crecer y aún así toda la pantalla sea “scrollable”
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _NoGlowIosScrollBehavior extends ScrollBehavior {
  const _NoGlowIosScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    // Sin glow azul/amarillo feo
    return child;
  }

  // Opcional: habilitamos gestos táctiles amigables en Web
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
