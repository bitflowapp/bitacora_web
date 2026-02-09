import 'package:bitacora_web/services/engine_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalize adds https scheme and trims trailing slash', () {
    expect(EngineConfig.normalize('example.com/'), 'https://example.com');
    expect(EngineConfig.normalize('https://host.tld///'), 'https://host.tld');
    expect(EngineConfig.normalize('  http://foo  '), 'http://foo');
  });

  test('isValidBaseUrl validates scheme and host', () {
    expect(EngineConfig.isValidBaseUrl('https://api.example.com'), isTrue);
    expect(EngineConfig.isValidBaseUrl('http://127.0.0.1:8001'), isTrue);
    expect(EngineConfig.isValidBaseUrl('ftp://bad'), isFalse);
    expect(EngineConfig.isValidBaseUrl('http://'), isFalse);
    expect(EngineConfig.isValidBaseUrl(''), isFalse);
  });
}
