import 'dart:typed_data';

enum WebCameraCaptureStatus { success, cancelled, blocked, error }

class WebCameraCaptureResult {
  const WebCameraCaptureResult._({
    required this.status,
    this.bytes,
    this.name = '',
    this.mime = '',
    this.error,
  });

  final WebCameraCaptureStatus status;
  final Uint8List? bytes;
  final String name;
  final String mime;
  final String? error;

  factory WebCameraCaptureResult.success({
    required Uint8List bytes,
    required String name,
    required String mime,
  }) {
    return WebCameraCaptureResult._(
      status: WebCameraCaptureStatus.success,
      bytes: bytes,
      name: name,
      mime: mime,
    );
  }

  factory WebCameraCaptureResult.cancelled() =>
      const WebCameraCaptureResult._(status: WebCameraCaptureStatus.cancelled);

  factory WebCameraCaptureResult.blocked(String message) =>
      WebCameraCaptureResult._(
        status: WebCameraCaptureStatus.blocked,
        error: message.trim().isEmpty ? 'Bloqueado' : message.trim(),
      );

  factory WebCameraCaptureResult.error(String message) =>
      WebCameraCaptureResult._(
        status: WebCameraCaptureStatus.error,
        error: message.trim().isEmpty ? 'Error desconocido' : message.trim(),
      );
}
