import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<String?> persistShareTempFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  if (fileName.trim().isEmpty || bytes.isEmpty) return null;
  try {
    final dir = await getTemporaryDirectory();
    final safeName = _safeFileName(fileName);
    final path = p.join(
      dir.path,
      'bitflow_share_${DateTime.now().millisecondsSinceEpoch}_$safeName',
    );
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

String _safeFileName(String raw) {
  final trimmed = raw.trim().isEmpty ? 'bitflow_export.bin' : raw.trim();
  return trimmed.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}
