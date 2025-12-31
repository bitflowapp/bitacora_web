import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

class VisualViewportInsetsController {
  final ValueNotifier<double> bottomInset = ValueNotifier<double>(0);

  Timer? _debounce;
  bool _disposed = false;

  StreamSubscription? _vvResizeSub;
  StreamSubscription? _vvScrollSub;
  StreamSubscription? _winResizeSub;

  // Importante: usamos addEventListener (focusin/out) en vez de getters inexistentes.
  late final html.EventListener _focusListener;

  VisualViewportInsetsController() {
    _focusListener = (html.Event _) => _schedule();

    _recalc();

    final vv = html.window.visualViewport;
    if (vv != null) {
      _vvResizeSub = vv.onResize.listen((_) => _schedule());
      _vvScrollSub = vv.onScroll.listen((_) => _schedule());
    }
    _winResizeSub = html.window.onResize.listen((_) => _schedule());

    // focusin/out con capture=true para agarrar inputs internos
    html.document.addEventListener('focusin', _focusListener, true);
    html.document.addEventListener('focusout', _focusListener, true);
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
      final ot = (vv.offsetTop ?? 0).toDouble();
      final visibleBottom = ot + vvH;
      inset = math.max(0, innerH - visibleBottom);
    }

    if ((bottomInset.value - inset).abs() > 0.5) {
      bottomInset.value = inset;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _debounce?.cancel();
    _vvResizeSub?.cancel();
    _vvScrollSub?.cancel();
    _winResizeSub?.cancel();

    try {
      html.document.removeEventListener('focusin', _focusListener, true);
      html.document.removeEventListener('focusout', _focusListener, true);
    } catch (_) {}

    bottomInset.dispose();
  }
}
