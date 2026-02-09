import 'dart:io';

class AtomicFileWriter {
  const AtomicFileWriter();

  bool get isSupported => true;

  Future<void> writeStringAtomic(
    String path,
    String data, {
    bool simulateSwapFailure = false,
  }) async {
    final target = File(path);
    await target.parent.create(recursive: true);

    final nonce = DateTime.now().microsecondsSinceEpoch;
    final temp = File('$path.tmp.$nonce');
    final backup = File('$path.bak.$nonce');

    var movedCurrentToBackup = false;
    try {
      final raf = await temp.open(mode: FileMode.writeOnly);
      try {
        await raf.writeString(data);
        await raf.flush();
      } finally {
        await raf.close();
      }

      if (await target.exists()) {
        await target.rename(backup.path);
        movedCurrentToBackup = true;
      }

      if (simulateSwapFailure) {
        throw FileSystemException('Simulated atomic swap failure', path);
      }

      await temp.rename(path);

      if (await backup.exists()) {
        await backup.delete();
      }
    } catch (_) {
      if (movedCurrentToBackup &&
          await backup.exists() &&
          !await target.exists()) {
        try {
          await backup.rename(path);
        } catch (_) {}
      }
      rethrow;
    } finally {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {}
      }
    }
  }
}
