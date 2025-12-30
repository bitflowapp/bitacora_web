/* ignore_for_file: avoid_web_libraries_in_flutter */
import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'dart:html' as html;
import 'dart:js_util' as jsu;

class WebUser {
  final String sub, name, email, picture;
  const WebUser({required this.sub, required this.name, required this.email, required this.picture});
}

class AuthWeb {
  AuthWeb._();
  static final ValueNotifier<WebUser?> user = ValueNotifier<WebUser?>(null);
  static bool _inited = false;
  static html.EventListener? _listener;

  static void init() {
    if (_inited) return; _inited = true;
    if (!kIsWeb) return;

    void refresh(_) {
      try {
        final obj = jsu.getProperty(html.window, 'BitacoraAuth');
        if (obj == null) { user.value = null; return; }
        final u = jsu.callMethod(obj, 'getUser', const []);
        if (u == null) { user.value = null; return; }
        user.value = WebUser(
          sub: (jsu.getProperty(u, 'sub') as String?) ?? '',
          name: (jsu.getProperty(u, 'name') as String?) ?? '',
          email:(jsu.getProperty(u, 'email') as String?) ?? '',
          picture:(jsu.getProperty(u, 'picture') as String?) ?? '',
        );
      } catch (_) { user.value = null; }
    }

    refresh(null);
    _listener = (e) => refresh(e);
    html.window.addEventListener('auth:changed', _listener!);
  }

  static void signIn() {
    if (!kIsWeb) return;
    try {
      final obj = jsu.getProperty(html.window, 'BitacoraAuth');
      if (obj != null) jsu.callMethod(obj, 'signIn', const []);
    } catch (_) {}
  }

  static void signOut() {
    if (!kIsWeb) return;
    try {
      final obj = jsu.getProperty(html.window, 'BitacoraAuth');
      if (obj != null) jsu.callMethod(obj, 'logout', const []);
    } catch (_) {}
  }
}


