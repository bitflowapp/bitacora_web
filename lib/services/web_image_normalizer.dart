import 'dart:typed_data';

import 'web_image_normalizer_stub.dart'
    if (dart.library.html) 'web_image_normalizer_web.dart';

class WebImageNormalizationRequest {
  const WebImageNormalizationRequest({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    this.source,
    this.maxSide = 1600,
    this.thumbMaxSide = 560,
    this.jpegQuality = 0.85,
    this.thumbJpegQuality = 0.78,
  });

  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final Object? source;
  final int maxSide;
  final int thumbMaxSide;
  final double jpegQuality;
  final double thumbJpegQuality;
}

class WebImageNormalizationResult {
  const WebImageNormalizationResult({
    required this.bytes,
    required this.mimeType,
    required this.fileName,
    this.thumbBytes,
  });

  final Uint8List bytes;
  final String mimeType;
  final String fileName;
  final Uint8List? thumbBytes;
}

class WebImageNormalizationException implements Exception {
  const WebImageNormalizationException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

abstract class WebImageNormalizer {
  static WebImageNormalizer get I => WebImageNormalizerImpl();

  Future<WebImageNormalizationResult?> normalize(
    WebImageNormalizationRequest request,
  );
}
