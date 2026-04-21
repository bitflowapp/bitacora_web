import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_web/services/engine_config.dart';

void main() {
  group('EngineConfig.isAllowedEngineHost — allowlist', () {
    // Note: in debug mode isAllowedEngineHost always returns true.
    // These tests verify the normalize + parse logic and that
    // known-safe hosts pass the pattern check regardless of mode.

    test('localhost is allowed', () {
      expect(EngineConfig.isAllowedEngineHost('http://localhost:8001'), isTrue);
    });

    test('127.0.0.1 is allowed', () {
      expect(EngineConfig.isAllowedEngineHost('http://127.0.0.1:8001'), isTrue);
    });

    test('trycloudflare.com subdomain is allowed', () {
      expect(
        EngineConfig.isAllowedEngineHost(
            'https://dock-strange-host.trycloudflare.com'),
        isTrue,
      );
    });

    test('ngrok-free.app subdomain is allowed', () {
      expect(
        EngineConfig.isAllowedEngineHost('https://abc123.ngrok-free.app'),
        isTrue,
      );
    });

    test('empty string is rejected', () {
      expect(EngineConfig.isAllowedEngineHost(''), isFalse);
    });

    test('URL with unparseable host is rejected', () {
      // An empty host after normalization is always rejected regardless of mode.
      expect(EngineConfig.isAllowedEngineHost('https:///no-host'), isFalse);
    });
  });

  group('EngineConfig.isValidBaseUrl', () {
    test('https URL is valid', () {
      expect(
        EngineConfig.isValidBaseUrl('https://example.trycloudflare.com'),
        isTrue,
      );
    });

    test('empty string is invalid', () {
      expect(EngineConfig.isValidBaseUrl(''), isFalse);
    });

    test('normalize drops trailing slash', () {
      expect(
        EngineConfig.normalize('https://example.com/'),
        'https://example.com',
      );
    });

    test('normalize adds https when scheme missing', () {
      final n = EngineConfig.normalize('example.com');
      expect(n, startsWith('https://'));
    });
  });
}
