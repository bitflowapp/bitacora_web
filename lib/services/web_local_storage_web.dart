import 'package:bitacora_web/web/html_compat.dart' as html;

import 'web_local_storage.dart';

class WebLocalStorageImpl implements WebLocalStorage {
  @override
  String? getItem(String key) {
    try {
      return html.window.localStorage[key];
    } catch (_) {
      return null;
    }
  }

  @override
  void setItem(String key, String value) {
    try {
      html.window.localStorage[key] = value;
    } catch (_) {}
  }
}
