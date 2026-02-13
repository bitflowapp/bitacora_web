import 'package:bitacora_web/services/about_diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('build diagnostics text is non-empty and contains version', () {
    final text = buildAboutDiagnosticsText(
      AboutDiagnosticsPayload(
        version: '1.0.2',
        build: '3',
        platform: 'android',
        isWeb: false,
        reducedMotion: true,
        timestamp: DateTime.utc(2026, 2, 13, 23, 55),
        sheetName: 'Parte diario',
        rows: 12,
        cols: 6,
      ),
    );

    expect(text.trim().isNotEmpty, isTrue);
    expect(text, contains('version=1.0.2'));
    expect(text, contains('build=3'));
  });
}
