import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKvKeys {
  static const String bioEnabled = 'bio_enabled';
  static const String bioLockOnOpen = 'bio_lock_on_open';
  static const String lastEmail = 'last_email';
  static const String lastLoginAt = 'last_login_at';
}

class SecureKv {
  SecureKv._();

  static final SecureKv I = SecureKv._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Future<void> writeString(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> readString(String key) async {
    return _storage.read(key: key);
  }

  Future<void> writeBool(String key, bool value) async {
    await _storage.write(key: key, value: value ? 'true' : 'false');
  }

  Future<bool> readBool(String key, {bool defaultValue = false}) async {
    final raw = await _storage.read(key: key);
    if (raw == null) return defaultValue;
    return raw.toLowerCase() == 'true';
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
