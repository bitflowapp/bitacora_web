// lib/services/keyboard_insets_controller_web.dart
// Controlador de insets de teclado (web con visualViewport).

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class KeyboardInsetsController with WidgetsBindingObserver {
  KeyboardInsetsController({this.onLog});

  final ValueChanged<String>? onLog;

  // Raw CSS px reportado por visualViewport / viewport real.
  final ValueNotifier<double> keyboardInset = ValueNotifier<double>(0.0);

  // Logical px usados por widgets Flutter.
  final ValueNotifier<double> kbInsetDp = ValueNotifier<double>(0.0);

  double _mqInset = 0.0;
  double _platformInset = 0.0;
  double _visualInsetPx = 0.0;
  double _lastNonZero = 0.0;
  DateTime? _lastNonZeroAt;
  Timer? _throttleT;

  StreamSubscription<html.Event>? _vvResizeSub;
  StreamSubscription<html.Event>? _vvScrollSub;
  StreamSubscription<html.Event>? _windowResizeSub;

  late final html.EventListener _focusListener;
  late final html.EventListener _windowScrollListener;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
    _focusListener = (_) => _updateFromVisualViewport();
    _windowScrollListener = (_) => _updateFromVisualViewport();
    _attachVisualViewport();
    _updateFromPlatform();
    _updateFromVisualViewport();
  }

  @override
  void dispose() {
    _throttleT?.cancel();
    _vvResizeSub?.cancel();
    _vvScrollSub?.cancel();
    _windowResizeSub?.cancel();
    try {
      html.document.removeEventListener('focusin', _focusListener, true);
      html.document.removeEventListener('focusout', _focusListener, true);
      html.window.removeEventListener('scroll', _windowScrollListener, true);
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    keyboardInset.dispose();
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
    _windowResizeSub = html.window.onResize.listen(
      (_) => _updateFromVisualViewport(),
    );

    html.document.addEventListener('focusin', _focusListener, true);
    html.document.addEventListener('focusout', _focusListener, true);
    html.window.addEventListener('scroll', _windowScrollListener, true);
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
      _visualInsetPx = 0.0;
      _scheduleEmit();
      return;
    }

    final innerH = (html.window.innerHeight ?? 0).toDouble();
    final viewportH = (vv.height ?? 0).toDouble();
    final offsetTop = (vv.offsetTop ?? 0).toDouble();

    final insetPx = innerH - (viewportH + offsetTop);
    _visualInsetPx = math.max(0.0, insetPx);

    _scheduleEmit();
  }

  void _scheduleEmit() {
    if (_throttleT?.isActive ?? false) return;
    _throttleT = Timer(const Duration(milliseconds: 32), _emit);
  }

  void _emit() {
    final dpr = (html.window.devicePixelRatio ?? 1.0).toDouble().clamp(
      1.0,
      8.0,
    );
    final visualInsetDp = _visualInsetPx / dpr;
    final rawDp = math.max(_mqInset, math.max(_platformInset, visualInsetDp));
    var nextDp = rawDp;

    if (nextDp > 1.0) {
      _lastNonZero = nextDp;
      _lastNonZeroAt = DateTime.now();
    } else if (_lastNonZero > 1.0 &&
        _lastNonZeroAt != null &&
        DateTime.now().difference(_lastNonZeroAt!).inMilliseconds < 250) {
      nextDp = _lastNonZero;
    }

    nextDp = _smooth(nextDp);
    final nextPx = math.max(_visualInsetPx, nextDp * dpr);

    final changedDp = (nextDp - kbInsetDp.value).abs() >= 1.0;
    final changedPx = (nextPx - keyboardInset.value).abs() >= 1.0;
    if (!changedDp && !changedPx) return;

    kbInsetDp.value = nextDp;
    keyboardInset.value = nextPx;
    onLog?.call(
      '[KeyboardInsetsWeb] inset -> ${nextDp.toStringAsFixed(1)}dp (${nextPx.toStringAsFixed(1)}px)',
    );
  }

  double _smooth(double value) {
    if (kbInsetDp.value == 0.0) return value;
    return (kbInsetDp.value * 0.6) + (value * 0.4);
  }
}
