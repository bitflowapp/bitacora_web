import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

typedef PhotoPathReader = Future<Uint8List?> Function(String path);

class PhotoBytesResolver {
  const PhotoBytesResolver._();

  static Future<Uint8List?> resolve({
    required String path,
    required String dataB64,
    required String thumbB64,
    required PhotoPathReader readFromPath,
    String? debugTag,
  }) async {
    if (path.trim().isNotEmpty) {
      final bytes = await readFromPath(path.trim());
      if (bytes != null && bytes.isNotEmpty) {
        return bytes;
      }
    }

    final data = _decodeBase64Maybe(dataB64);
    if (data != null && data.isNotEmpty) return data;

    final thumb = _decodeBase64Maybe(thumbB64);
    if (thumb != null && thumb.isNotEmpty) return thumb;

    if (kDebugMode) {
      debugPrint(
        '[PhotoBytesResolver] bytes missing'
        ' tag=${debugTag ?? 'photo'}'
        ' path=${path.trim().isNotEmpty}'
        ' dataB64=${dataB64.trim().isNotEmpty}'
        ' thumbB64=${thumbB64.trim().isNotEmpty}',
      );
    }
    return null;
  }

  static Uint8List? _decodeBase64Maybe(String value) {
    var raw = value.trim();
    if (raw.isEmpty) return null;

    if (raw.startsWith('data:')) {
      final comma = raw.indexOf(',');
      if (comma >= 0 && comma < raw.length - 1) {
        raw = raw.substring(comma + 1);
      }
    }

    raw = raw.replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) return null;

    try {
      return Uint8List.fromList(base64Decode(raw));
    } catch (_) {
      return null;
    }
  }
}
