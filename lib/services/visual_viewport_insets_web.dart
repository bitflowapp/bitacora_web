import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Soluciona el bug típico de Flutter Web en iOS/Android:
/// el teclado cambia el viewport pero Flutter no actualiza layout hasta que tipeás.
///
/// Estrategia:
/// - Leer window.visualViewport (height + offsetTop) y compararlo con innerHeight.
/// - Escuchar resize/scroll del visualViewport y window.
/// - Debounce corto para estabilizar valores.
/// - Exponer bottomInset como ValueNotifier para animar padding.
class VisualViewportInsetsController {
  final ValueNotifier<double> bottomInset = ValueNotifier<double>(0);

  Timer? _debounce;
  bool _disposed = false;

  VisualViewportInsetsController() {
    _recalc();

    final vv = html.window.visualViewport;
    if (vv != null) {
      vv.onResize.listen((_) => _schedule());
      vv.onScroll.listen((_) => _schedule());
    }
    html.window.onResize.listen((_) => _schedule());
  }

  void recalcNow() {
    if (_disposed) return;
    _debounce?.cancel();
    _recalc();
  }

  void _schedule() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 16), _recalc);
  }

  void _recalc() {
    if (_disposed) return;

    final vv = html.window.visualViewport;
    final innerH = (html.window.innerHeight ?? 0).toDouble();
    double inset = 0;

    if (vv != null && innerH > 0) {
      final vvH = (vv.height ?? 0).toDouble();
      final offsetTop = (vv.offsetTop ?? 0).toDouble();
      final visibleBottom = offsetTop + vvH;
      inset = math.max(0, innerH - visibleBottom);
    }

    if ((bottomInset.value - inset).abs() > 0.5) {
      bottomInset.value = inset;
    }
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    bottomInset.dispose();
  }
}
