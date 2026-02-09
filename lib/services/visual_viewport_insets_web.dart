// lib/services/visual_viewport_insets_web.dart
//
// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// VisualViewportInsetsController (WEB)
/// Calcula un "bottomInset" real cuando aparece el teclado en iOS/Android Web.
/// Útil para padding inferior del editor / barra inferior.
///
/// Nota: HtmlDocument NO tiene onFocusIn/onFocusOut.
/// Para eso usamos addEventListener('focusin'/'focusout') en modo capture.
class VisualViewportInsetsController {
  final ValueNotifier<double> bottomInset = ValueNotifier<double>(0);

  Timer? _debounce;
  bool _disposed = false;

  StreamSubscription<html.Event>? _winResizeSub;
  StreamSubscription<html.Event>? _vvResizeSub;
  StreamSubscription<html.Event>? _vvScrollSub;
  StreamSubscription<html.Event>? _winFocusSub;
  StreamSubscription<html.Event>? _winBlurSub;

  late final void Function(html.Event) _docFocusInHandler;
  late final void Function(html.Event) _docFocusOutHandler;

  VisualViewportInsetsController() {
    // Primera medición
    _recalc();

    // VisualViewport (cuando existe) es lo más confiable para teclado en iOS.
    final vv = html.window.visualViewport;
    if (vv != null) {
      _vvResizeSub = vv.onResize.listen((_) => _schedule());
      _vvScrollSub = vv.onScroll.listen((_) => _schedule());
    }

    _winResizeSub = html.window.onResize.listen((_) => _schedule());

    // Eventos de foco generales
    _winFocusSub = html.window.onFocus.listen((_) => _schedule());
    _winBlurSub = html.window.onBlur.listen((_) => _schedule());

    // Foco real (capture) para cuando Flutter crea inputs invisibles
    _docFocusInHandler = (_) => _schedule();
    _docFocusOutHandler = (_) => _schedule();
    try {
      html.document.addEventListener('focusin', _docFocusInHandler, true);
      html.document.addEventListener('focusout', _docFocusOutHandler, true);
    } catch (_) {
      // En algunos entornos raros puede fallar; no es crítico.
    }
  }

  void recalcNow() {
    if (_disposed) return;
    _debounce?.cancel();
    _recalc();
  }

  void _schedule() {
    if (_disposed) return;
    _debounce?.cancel();

    // 16ms: un frame. Suficiente para que visualViewport estabilice altura/offset.
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

      // Visible bottom = offsetTop + height del visual viewport
      final visibleBottom = offsetTop + vvH;

      // Lo que queda "debajo" es teclado / UI
      inset = math.max(0, innerH - visibleBottom);
    }

    // Umbral para evitar “micro jitter”
    if ((bottomInset.value - inset).abs() > 0.5) {
      bottomInset.value = inset;
    }
  }

  void dispose() {
    _disposed = true;
    _debounce?.cancel();

    _winResizeSub?.cancel();
    _vvResizeSub?.cancel();
    _vvScrollSub?.cancel();
    _winFocusSub?.cancel();
    _winBlurSub?.cancel();

    try {
      html.document.removeEventListener('focusin', _docFocusInHandler, true);
      html.document.removeEventListener('focusout', _docFocusOutHandler, true);
    } catch (_) {}

    bottomInset.dispose();
  }
}
