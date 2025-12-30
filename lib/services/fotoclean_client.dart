// lib/services/fotoclean_client.dart
// Cliente para FotoClean PRO (/v1/auto-clean). Null-safety.
// Sin dependencias extra fuera de 'http'.

import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class FotoInput {
  final String name;
  final String? base64; // Usa uno de los dos
  final String? url;

  const FotoInput({required this.name, this.base64, this.url})
      : assert(base64 != null || url != null,
  'Debes proveer base64 o url');

  factory FotoInput.fromBase64({required String name, required String base64}) =>
      FotoInput(name: name, base64: base64, url: null);

  factory FotoInput.fromUrl({required String name, required String url}) =>
      FotoInput(name: name, base64: null, url: url);

  Map<String, dynamic> toJson() => {
    'name': name,
    if (base64 != null) 'base64': base64,
    if (url != null) 'url': url,
  };
}

class OptimizedImage {
  final String name;
  final int width;
  final int height;
  final double blur;
  final String hash;
  final String mime;
  final int bytesIn;
  final int bytesOut;
  final String base64;

  const OptimizedImage({
    required this.name,
    required this.width,
    required this.height,
    required this.blur,
    required this.hash,
    required this.mime,
    required this.bytesIn,
    required this.bytesOut,
    required this.base64,
  });

  Uint8List get bytes => base64Decode(base64);

  factory OptimizedImage.fromJson(Map<String, dynamic> j) {
    return OptimizedImage(
      name: j['name'] as String,
      width: (j['width'] as num).toInt(),
      height: (j['height'] as num).toInt(),
      blur: (j['blur'] as num).toDouble(),
      hash: j['hash'] as String,
      mime: j['mime'] as String,
      bytesIn: (j['bytesIn'] as num).toInt(),
      bytesOut: (j['bytesOut'] as num).toInt(),
      base64: j['base64'] as String,
    );
  }
}

class RemovedImage {
  final String name;
  final double blur;
  final String reason;
  final String hash;

  const RemovedImage({
    required this.name,
    required this.blur,
    required this.reason,
    required this.hash,
  });

  factory RemovedImage.fromJson(Map<String, dynamic> j) {
    return RemovedImage(
      name: j['name'] as String,
      blur: (j['blur'] as num).toDouble(),
      reason: j['reason'] as String,
      hash: j['hash'] as String,
    );
  }
}

class OptimizedBatch {
  final bool ok;
  final Map<String, dynamic> stats;
  final List<OptimizedImage> kept;
  final List<RemovedImage> removed;

  const OptimizedBatch({
    required this.ok,
    required this.stats,
    required this.kept,
    required this.removed,
  });

  factory OptimizedBatch.fromJson(Map<String, dynamic> j) {
    final keptList = (j['kept'] as List<dynamic>? ?? [])
        .map((e) => OptimizedImage.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final remList = (j['removed'] as List<dynamic>? ?? [])
        .map((e) => RemovedImage.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    return OptimizedBatch(
      ok: j['ok'] == true,
      stats: (j['stats'] as Map?)?.cast<String, dynamic>() ?? const {},
      kept: keptList,
      removed: remList,
    );
  }
}

class FotoCleanClient {
  final String baseUrl; // p.ej. http://192.168.0.10:4010
  final String apiKey;
  final http.Client _http;

  FotoCleanClient({
    required this.baseUrl,
    required this.apiKey,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  Future<OptimizedBatch> autoClean({
    required List<FotoInput> images,
    int quality = 85,
    int maxWidth = 1600,
    String format = 'jpeg', // 'jpeg' | 'webp'
    bool dedup = true,
    int hashThreshold = 6,
    int blurMin = 0, // 0 para no filtrar en primeras pruebas
  }) async {
    if (images.isEmpty) {
      throw ArgumentError('images vacío');
    }
    final uri = Uri.parse('$baseUrl/v1/auto-clean');
    final body = jsonEncode({
      'images': images.map((e) => e.toJson()).toList(),
      'quality': quality,
      'maxWidth': maxWidth,
      'format': format,
      'dedup': dedup,
      'hashThreshold': hashThreshold,
      'blurMin': blurMin,
    });
    final resp = await _http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      },
      body: body,
    );

    if (resp.statusCode == 401) {
      throw Exception('Unauthorized: revisá x-api-key');
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          'HTTP ${resp.statusCode}: ${resp.body.isNotEmpty ? resp.body : 'sin cuerpo'}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return OptimizedBatch.fromJson(decoded);
  }

  void close() {
    _http.close();
  }
}
