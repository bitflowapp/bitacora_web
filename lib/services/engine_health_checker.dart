import 'package:bitacora_web/services/engine_api.dart';
import 'package:bitacora_web/services/engine_config.dart';

/// Narrow interface used by editor startup/smoke health checks.
abstract class EngineHealthChecker {
  Future<Uri> resolveBaseUri();

  Future<void> ensureHealthyBase(
    String baseUrl, {
    List<String>? paths,
    Duration timeout,
  });

  Future<Map<String, dynamic>> getJsonFromBase(
    String baseUrl,
    String path, {
    Duration timeout,
    Map<String, String>? headers,
  });
}

class EngineApiHealthChecker implements EngineHealthChecker {
  EngineApiHealthChecker(this._engineApi);

  final EngineApi _engineApi;

  @override
  Future<Uri> resolveBaseUri() => _engineApi.resolveBaseUri();

  @override
  Future<void> ensureHealthyBase(
    String baseUrl, {
    List<String>? paths,
    Duration timeout = const Duration(seconds: 8),
  }) {
    return _engineApi.ensureHealthyBase(
      baseUrl,
      paths: paths,
      timeout: timeout,
    );
  }

  @override
  Future<Map<String, dynamic>> getJsonFromBase(
    String baseUrl,
    String path, {
    Duration timeout = const Duration(seconds: 8),
    Map<String, String>? headers,
  }) {
    return _engineApi.getJsonFromBase(
      baseUrl,
      path,
      timeout: timeout,
      headers: headers,
    );
  }
}

/// Test-safe checker that never performs network calls.
class FakeEngineHealthChecker implements EngineHealthChecker {
  const FakeEngineHealthChecker({
    this.baseUrl = EngineConfig.defaultLanBaseUrl,
    this.response = const <String, dynamic>{'ok': true},
  });

  final String baseUrl;
  final Map<String, dynamic> response;

  @override
  Future<Uri> resolveBaseUri() async {
    final normalized = EngineConfig.normalize(baseUrl);
    if (!EngineConfig.isValidBaseUrl(normalized)) {
      return Uri.parse(EngineConfig.defaultLanBaseUrl);
    }
    return Uri.parse(normalized);
  }

  @override
  Future<void> ensureHealthyBase(
    String baseUrl, {
    List<String>? paths,
    Duration timeout = const Duration(seconds: 8),
  }) async {}

  @override
  Future<Map<String, dynamic>> getJsonFromBase(
    String baseUrl,
    String path, {
    Duration timeout = const Duration(seconds: 8),
    Map<String, String>? headers,
  }) async {
    return Map<String, dynamic>.from(response);
  }
}
