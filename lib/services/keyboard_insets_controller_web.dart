// lib/services/keyboard_insets_controller_web.dart
// Controlador de insets de teclado (web con visualViewport).

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:math' as math;
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class KeyboardInsetsController with WidgetsBindingObserver {
  KeyboardInsetsController({this.onLog});

  final ValueChanged<String>? onLog;
  final ValueNotifier<double> kbInsetDp = ValueNotifier<double>(0.0);

  double _mqInset = 0.0;
  double _platformInset = 0.0;
  double _visualInset = 0.0;
  double _lastNonZero = 0.0;
  DateTime? _lastNonZeroAt;
  Timer? _debounceT;

  StreamSubscription<html.Event>? _vvResizeSub;
  StreamSubscription<html.Event>? _vvScrollSub;
  StreamSubscription<html.Event>? _windowResizeSub;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
    _attachVisualViewport();
    _updateFromPlatform();
    _updateFromVisualViewport();
  }

  @override
  void dispose() {
    _debounceT?.cancel();
    _vvResizeSub?.cancel();
    _vvScrollSub?.cancel();
    _windowResizeSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    kbInsetDp.dispose();
  }

  void reportMediaQueryInset(double value) {
    if ((value - _mqInset).abs() < 0.5) return;
    _mqInset = value;
    _scheduleEmit();
  }

  @override
  void didChangeMetrics() {
    _updateFromPlatform();
    _updateFromVisualViewport();
  }

  void _attachVisualViewport() {
    final vv = html.window.visualViewport;
    if (vv != null) {
      _vvResizeSub = vv.onResize.listen((_) => _updateFromVisualViewport());
      _vvScrollSub = vv.onScroll.listen((_) => _updateFromVisualViewport());
    }
    _windowResizeSub =
        html.window.onResize.listen((_) => _updateFromVisualViewport());
  }

  void _updateFromPlatform() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isNotEmpty) {
      final view = views.first;
      _platformInset = view.viewInsets.bottom / view.devicePixelRatio;
    } else {
      _platformInset = 0.0;
    }
    _scheduleEmit();
  }

  void _updateFromVisualViewport() {
    final vv = html.window.visualViewport;
    if (vv == null) {
      _visualInset = 0.0;
      _scheduleEmit();
      return;
    }

    final innerH = (html.window.innerHeight ?? 0).toDouble();
    final viewportH = (vv.height ?? 0).toDouble();
    final offsetTop = (vv.offsetTop ?? 0).toDouble();

    // Inset “real” aproximado: lo que quedó tapado abajo por el teclado/viewport.
    final inset = innerH - (viewportH + offsetTop);
    _visualInset = math.max(0.0, inset);

    _scheduleEmit();
  }

  void _scheduleEmit() {
    _debounceT?.cancel();
    _debounceT = Timer(const Duration(milliseconds: 50), _emit);
  }

  void _emit() {
    final raw = math.max(_mqInset, math.max(_platformInset, _visualInset));
    var next = raw;

    if (next > 1.0) {
      _lastNonZero = next;
      _lastNonZeroAt = DateTime.now();
    } else if (_lastNonZero > 1.0 &&
        _lastNonZeroAt != null &&
        DateTime.now().difference(_lastNonZeroAt!).inMilliseconds < 250) {
      next = _lastNonZero;
    }

    next = _smooth(next);
    if ((next - kbInsetDp.value).abs() < 1.0) return;

    kbInsetDp.value = next;
    onLog?.call('[KeyboardInsetsWeb] inset -> ${next.toStringAsFixed(1)}dp');
  }

  double _smooth(double value) {
    if (kbInsetDp.value == 0.0) return value;
    return (kbInsetDp.value * 0.6) + (value * 0.4);
  }
}
