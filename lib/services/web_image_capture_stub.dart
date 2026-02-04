import 'dart:typed_data';

enum WebImageCaptureStatus { success, cancelled, error }

class WebImageCaptureResult {
  const WebImageCaptureResult._({
    required this.status,
    this.bytes,
    this.name = '',
    this.mime = '',
    this.error,
  });

  final WebImageCaptureStatus status;
  final Uint8List? bytes;
  final String name;
  final String mime;
  final String? error;

  factory WebImageCaptureResult.success({
    required Uint8List bytes,
    required String name,
    required String mime,
  }) {
    return WebImageCaptureResult._(
      status: WebImageCaptureStatus.success,
      bytes: bytes,
      name: name,
      mime: mime,
    );
  }

  factory WebImageCaptureResult.cancelled() =>
      const WebImageCaptureResult._(status: WebImageCaptureStatus.cancelled);

  factory WebImageCaptureResult.error(String message) =>
      WebImageCaptureResult._(
        status: WebImageCaptureStatus.error,
        error: message.trim().isEmpty ? 'Error desconocido' : message.trim(),
      );
}

Future<WebImageCaptureResult> captureWebImage({
  required bool capture,
  double jpegQuality = 0.85,
}) async {
  return WebImageCaptureResult.error('Web image capture no disponible.');
}
