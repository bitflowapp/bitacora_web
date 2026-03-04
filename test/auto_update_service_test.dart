import 'dart:convert';

import 'package:bitacora_web/services/auto_update_service.dart';
import 'package:bitacora_web/services/force_update_service.dart';
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
}

class _FakeForceUpdateService implements ForceUpdateService {
  int invocations = 0;

  @override
  Future<ForceUpdateResult> forceUpdate({String? cacheBustValue}) async {
    invocations++;
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
  }
}
