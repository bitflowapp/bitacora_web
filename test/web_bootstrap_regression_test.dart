import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web bootstrap avoids duplicate service worker orchestration', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('window.__bitflowBootRetry'));
    expect(html, contains('href="landing"'));
    expect(
      html,
      contains("window.addEventListener('unhandledrejection'"),
    );
    expect(
      html,
      contains('version.json no respondio a tiempo; se uso fallback temporal.'),
    );

    expect(html, isNot(contains('hardenServiceWorkerUpdates(')));
    expect(html, isNot(contains('applyWaitingServiceWorker(')));
    expect(html, isNot(contains('navigator.serviceWorker.register(swUrl')));
  });
}
