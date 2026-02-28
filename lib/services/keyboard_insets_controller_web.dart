// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'package:bitacora_web/web/html_compat.dart' as html;import 'dart:math' as math;

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

  bool _focusProbeActive = false;
  double _focusProbeMax = 0.0;

  Timer? _emitThrottleT;
  Timer? _visualThrottleT;
  Timer? _focusProbeT;

  StreamSubscription<html.Event>? _vvResizeSub;
  StreamSubscription<html.Event>? _vvScrollSub;
  StreamSubscription<html.Event>? _windowResizeSub;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
    _attachVisualViewport();
    _updateFromPlatform();
    _updateFromVisualViewport();
    _scheduleEmit(forceNow: true);
  }

  void dispose() {
    _emitThrottleT?.cancel();
    _visualThrottleT?.cancel();
    _focusProbeT?.cancel();
    _vvResizeSub?.cancel();
    _vvScrollSub?.cancel();
    _windowResizeSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    kbInsetDp.dispose();
  }

  void reportMediaQueryInset(double value) {
    final next = value < 0 ? 0.0 : value;
    if ((next - _mqInset).abs() < 0.5) return;
    _mqInset = next;
    _scheduleEmit();
  }

  void beginFocusProbe() {
    final vv = html.window.visualViewport;
    if (vv == null) {
      _updateFromVisualViewport();
      return;
    }

    _focusProbeT?.cancel();
    _focusProbeActive = true;
    _focusProbeMax = _computeVisualViewportInset();
    _visualInset = math.max(_visualInset, _focusProbeMax);
    _scheduleEmit(forceNow: true);

    final startedAt = DateTime.now();
    _focusProbeT = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final sample = _computeVisualViewportInset();
      if (sample > _focusProbeMax) {
        _focusProbeMax = sample;
      }
      final probedInset = math.max(sample, _focusProbeMax);
      if ((probedInset - _visualInset).abs() > 0.5) {
        _visualInset = probedInset;
      }
      _scheduleEmit();

      if (DateTime.now().difference(startedAt).inMilliseconds >= 250) {
        _focusProbeActive = false;
        _visualInset = math.max(_visualInset, _focusProbeMax);
        timer.cancel();
        _focusProbeT = null;
        _scheduleEmit(forceNow: true);
      }
    });
  }

  @override
  void didChangeMetrics() {
    _updateFromPlatform();
    _updateFromVisualViewport();
  }

  void _attachVisualViewport() {
    final vv = html.window.visualViewport;
    if (vv != null) {
      _vvResizeSub = vv.onResize.listen((_) => _scheduleVisualRefresh());
      _vvScrollSub = vv.onScroll.listen((_) => _scheduleVisualRefresh());
    }
    _windowResizeSub =
        html.window.onResize.listen((_) => _scheduleVisualRefresh());
  }

  void _scheduleVisualRefresh() {
    if (_visualThrottleT != null) return;
    _visualThrottleT = Timer(const Duration(milliseconds: 16), () {
      _visualThrottleT = null;
      _updateFromVisualViewport();
    });
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

  double _computeVisualViewportInset() {
    final vv = html.window.visualViewport;
    if (vv == null) return 0.0;
    final innerH = (html.window.innerHeight ?? 0).toDouble();
    if (innerH <= 0) return 0.0;
    final viewportH = (vv.height ?? 0).toDouble();
    final offsetTop = (vv.offsetTop ?? 0).toDouble();
    return math.max(0.0, innerH - (viewportH + offsetTop));
  }

  void _updateFromVisualViewport() {
    final nextVisual = _computeVisualViewportInset();
    final resolvedVisual =
        _focusProbeActive ? math.max(nextVisual, _focusProbeMax) : nextVisual;
    if ((resolvedVisual - _visualInset).abs() <= 0.5) return;
    _visualInset = resolvedVisual;
    _scheduleEmit();
  }

  void _scheduleEmit({bool forceNow = false}) {
    if (forceNow) {
      _emit();
      return;
    }
    if (_emitThrottleT != null) return;
    _emitThrottleT = Timer(const Duration(milliseconds: 16), () {
      _emitThrottleT = null;
      _emit();
    });
  }

  void _emit() {
    var next = math.max(_mqInset, math.max(_platformInset, _visualInset));
    if (_focusProbeActive && _focusProbeMax > next) {
      next = _focusProbeMax;
    }

    if (next > 1.0) {
      _lastNonZero = next;
      _lastNonZeroAt = DateTime.now();
    } else if (_lastNonZero > 1.0 &&
        _lastNonZeroAt != null &&
        DateTime.now().difference(_lastNonZeroAt!).inMilliseconds < 250) {
      next = _lastNonZero;
    }

    if ((next - kbInsetDp.value).abs() <= 1.0) return;
    kbInsetDp.value = next;
    onLog?.call('[KeyboardInsetsWeb] inset -> ${next.toStringAsFixed(1)}dp');
  }
}
