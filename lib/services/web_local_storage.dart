import 'web_local_storage_stub.dart'
    if (dart.library.html) 'web_local_storage_web.dart';

abstract class WebLocalStorage {
  static WebLocalStorage get I => WebLocalStorageImpl();

  String? getItem(String key);
  void setItem(String key, String value);
}
