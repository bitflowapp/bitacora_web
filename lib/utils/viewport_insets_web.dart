// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

double visualViewportKeyboardInset() {
  try {
    final vv = html.window.visualViewport;
    if (vv == null) return 0.0;
    final innerH = html.window.innerHeight?.toDouble() ?? 0.0;
    final vvH = vv.height ?? 0;
    final top = vv.offsetTop ?? 0;
    final overlap = innerH - vvH - top;
    return overlap > 0 ? overlap : 0.0;
  } catch (_) {
    return 0.0;
  }
}

void Function()? attachViewportListener(void Function() onChange) {
  try {
    final vv = html.window.visualViewport;
    if (vv == null) return null;
    void handler(_) => onChange();
    vv.addEventListener('resize', handler);
    vv.addEventListener('scroll', handler);
    return () {
      vv.removeEventListener('resize', handler);
      vv.removeEventListener('scroll', handler);
    };
  } catch (_) {
    return null;
  }
}
