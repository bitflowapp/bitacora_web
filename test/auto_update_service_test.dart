import 'dart:convert';

import 'package:bitacora_web/services/auto_update_service.dart';
import 'package:bitacora_web/services/force_update_service.dart';
import 'package:bitacora_web/services/web_local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AutoUpdateService tolerates invalid version.json payload', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final force = _FakeForceUpdateService();
    final client = MockClient((_) async {
      final bytes = utf8.encode('{not-json');
      return http.Response.bytes(bytes, 200);
    });

    final service = AutoUpdateService(
      client: client,
      forceUpdateService: force,
      webOverride: true,
      isOnline: () => true,
      allowUnresolvedLocalBuild: true,
    );

    await service.maybeAutoUpdateOnStartup();

    expect(service.reloadTriggered, isFalse);
    expect(force.invocations, 0);
  });

  test('AutoUpdateService exits quietly when offline', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final force = _FakeForceUpdateService();
    final client = MockClient((_) async {
      throw StateError('network should not be called while offline');
    });

    final service = AutoUpdateService(
      client: client,
      forceUpdateService: force,
      webOverride: true,
      isOnline: () => false,
    );

    await service.maybeAutoUpdateOnStartup();

    expect(service.reloadTriggered, isFalse);
    expect(force.invocations, 0);
  });

  test('AutoUpdateService does not reload when lastReloadAt is under 60s',
      () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final now = DateTime.utc(2026, 3, 4, 3, 55, 0);
    final storage = _MemoryWebLocalStorage(<String, String>{
      'bitflow.auto_update.last_reload_at_ms.v1': now
          .subtract(const Duration(seconds: 30))
          .millisecondsSinceEpoch
          .toString(),
    });
    final force = _FakeForceUpdateService();
    final client = MockClient((_) async {
      final payload = utf8.encode(
        '{"buildId":"1.3.1+9-bbbb2222","gitSha":"bbbb2222"}',
      );
      return http.Response.bytes(payload, 200);
    });

    final service = AutoUpdateService(
      client: client,
      forceUpdateService: force,
      webOverride: true,
      isOnline: () => true,
      nowProvider: () => now,
      webLocalStorage: storage,
      localGitShaOverride: 'aaaa1111',
      localBuildIdOverride: '1.3.1+9-aaaa1111',
    );

    await service.maybeAutoUpdateOnStartup();

    expect(service.reloadTriggered, isFalse);
    expect(force.forceCalls, 0);
    expect(force.reloadCalls, 0);
  });

  test('AutoUpdateService prefers gitSha comparison over buildId', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final now = DateTime.utc(2026, 3, 4, 3, 56, 0);
    final storage = _MemoryWebLocalStorage(<String, String>{});
    final force = _FakeForceUpdateService();
    final client = MockClient((_) async {
      final payload = utf8.encode(
        '{"buildId":"1.3.1+9-samebuild","gitSha":"bbbb2222"}',
      );
      return http.Response.bytes(payload, 200);
    });

    final service = AutoUpdateService(
      client: client,
      forceUpdateService: force,
      webOverride: true,
      isOnline: () => true,
      nowProvider: () => now,
      webLocalStorage: storage,
      localGitShaOverride: 'aaaa1111',
      localBuildIdOverride: '1.3.1+9-samebuild',
    );

    await service.maybeAutoUpdateOnStartup();

    expect(service.reloadTriggered, isTrue);
    expect(force.forceCalls, 0);
    expect(force.reloadCalls, 1);
  });
}

class _FakeForceUpdateService implements ForceUpdateService {
  int invocations = 0;
  int forceCalls = 0;
  int reloadCalls = 0;

  @override
  Future<ForceUpdateResult> forceUpdate({String? cacheBustValue}) async {
    invocations++;
    forceCalls++;
    return const ForceUpdateResult(
      supported: true,
      reloaded: true,
      message: 'ok',
    );
  }

  @override
  Future<bool> hasWebCacheArtifacts() async => false;

  @override
  Future<void> reloadWithCacheBust(String cacheBustValue) async {
    invocations++;
    reloadCalls++;
  }
}

class _MemoryWebLocalStorage implements WebLocalStorage {
  _MemoryWebLocalStorage(this._store);

  final Map<String, String> _store;

  @override
  String? getItem(String key) => _store[key];

  @override
  void setItem(String key, String value) {
    _store[key] = value;
  }
}
