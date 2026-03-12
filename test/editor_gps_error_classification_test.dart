import 'package:bitacora_web/screens/editor_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('classifyGpsErrorForUi maps permission denied forever to app settings', () {
    final result = classifyGpsErrorForUi(
      code: 'permission_denied_forever',
      rawError: 'denied forever',
    );

    expect(result.action, GpsErrorAction.openAppSettings);
    expect(result.message, contains('Ajustes'));
  });

  test('classifyGpsErrorForUi maps disabled service to location settings', () {
    final result = classifyGpsErrorForUi(
      code: 'service_disabled',
      rawError: 'service disabled',
    );

    expect(result.action, GpsErrorAction.openLocationSettings);
    expect(result.message, contains('apagado'));
  });

  test('classifyGpsErrorForUi maps timeout to retry guidance', () {
    final result = classifyGpsErrorForUi(code: 'timeout', rawError: 'timeout');

    expect(result.action, GpsErrorAction.none);
    expect(result.message, contains('a tiempo'));
  });
}
