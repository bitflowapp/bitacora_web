import 'dart:io';

import 'package:bitacora_web/core/atomic_file_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('atomic write keeps last-good data on simulated swap failure', () async {
    final writer = const AtomicFileWriter();
    if (!writer.isSupported) {
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp('bitflow_atomic_');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final file = File('${tempDir.path}${Platform.pathSeparator}sheet.json');
    await file.writeAsString('{"version":1}', flush: true);

    await expectLater(
      writer.writeStringAtomic(
        file.path,
        '{"version":2}',
        simulateSwapFailure: true,
      ),
      throwsA(isA<FileSystemException>()),
    );

    final after = await file.readAsString();
    expect(after, '{"version":1}');
  });
}
