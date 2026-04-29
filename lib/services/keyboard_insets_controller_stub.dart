// lib/services/keyboard_insets_controller_stub.dart
// Controlador de insets de teclado (no-web).

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class KeyboardInsetsController with WidgetsBindingObserver {
  KeyboardInsetsController({this.onLog});

  final ValueChanged<String>? onLog;
  final ValueNotifier<double> kbInsetDp = ValueNotifier<double>(0.0);

  double _mqInset = 0.0;
  double _platformInset = 0.0;
  double _lastNonZero = 0.0;
  DateTime? _lastNonZeroAt;
  Timer? _debounceT;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
    _updateFromPlatform();
  }

  void dispose() {
    _debounceT?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    kbInsetDp.dispose();
  }

  void reportMediaQueryInset(double value) {
    if ((value - _mqInset).abs() < 0.5) return;
    _mqInset = value;
    _scheduleEmit();
  }

  void beginFocusProbe() {}

  @override
  void didChangeMetrics() {
    _updateFromPlatform();
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

  void _scheduleEmit() {
    _debounceT?.cancel();
    _debounceT = Timer(const Duration(milliseconds: 50), _emit);
  }

  void _emit() {
    final raw = math.max(_mqInset, _platformInset);
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
    onLog?.call('[KeyboardInsets] inset -> ${next.toStringAsFixed(1)}dp');
  }

  double _smooth(double value) {
    if (kbInsetDp.value == 0.0) return value;
    return (kbInsetDp.value * 0.6) + (value * 0.4);
  }
}
