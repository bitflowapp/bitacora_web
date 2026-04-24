import 'package:bitacora_web/core/app_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps attachment permission errors to friendly permission message', () {
    final err = AppErrorMapper.fromMessage(
      'NotAllowedError: Permission denied while opening camera',
      flow: AppErrorFlow.attachmentPermission,
    );

    expect(err.kind, AppErrorKind.permissionDenied);
    expect(err.userMessage, contains('Revisa permisos'));
  });

  test('attachment unknown errors do not expose technical cause codes', () {
    final err = AppErrorMapper.fromMessage(
      'unexpected_low_level_error',
      flow: AppErrorFlow.attachmentPermission,
    );

    expect(err.kind, AppErrorKind.unknown);
    expect(err.userMessage, isNot(contains('unknown')));
    expect(err.userMessage, isNot(contains('Causa')));
  });

  test('maps import invalid data errors to import invalid message', () {
    final err = AppErrorMapper.fromMessage(
      'No se encontro backup.json en el ZIP.',
      flow: AppErrorFlow.importData,
    );

    expect(err.kind, AppErrorKind.invalidData);
    expect(err.userMessage, contains('backup'));
  });
}
