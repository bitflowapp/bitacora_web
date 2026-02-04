import 'dart:async';
import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter
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
}) {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  if (capture) {
    input.setAttribute('capture', 'environment');
  }

  input.style.display = 'none';
  html.document.body?.append(input);

  final completer = Completer<WebImageCaptureResult>();
  StreamSubscription<html.Event>? changeSub;
  StreamSubscription<html.Event>? focusSub;
  String? objectUrl;
  var finished = false;

  void finish(WebImageCaptureResult result) {
    if (finished) return;
    finished = true;
    try {
      changeSub?.cancel();
      focusSub?.cancel();
    } catch (_) {}
    if (objectUrl != null) {
      try {
        html.Url.revokeObjectUrl(objectUrl!);
      } catch (_) {}
    }
    try {
      input.remove();
    } catch (_) {}
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  Future<Uint8List?> _blobToBytes(html.Blob blob) async {
    final reader = html.FileReader();
    reader.readAsArrayBuffer(blob);
    await reader.onLoadEnd.first;
    final result = reader.result;
    if (result is! ByteBuffer) return null;
    return Uint8List.view(result);
  }

  changeSub = input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      finish(WebImageCaptureResult.cancelled());
      return;
    }

    final file = files.first;
    objectUrl = html.Url.createObjectUrl(file);

    try {
      final img = html.ImageElement();
      final loadFuture = img.onLoad.first;
      final errFuture = img.onError.first;
      img.src = objectUrl!;
      await Future.any([loadFuture, errFuture]);

      if (img.naturalWidth == 0 || img.naturalHeight == 0) {
        finish(WebImageCaptureResult.error('No se pudo decodificar la imagen.'));
        return;
      }

      final canvas = html.CanvasElement(
        width: img.naturalWidth,
        height: img.naturalHeight,
      );
      final ctx = canvas.context2D;
      ctx.drawImageScaled(img, 0, 0, canvas.width!, canvas.height!);

      final blob = await canvas.toBlob('image/jpeg', jpegQuality);
      if (blob == null) {
        finish(WebImageCaptureResult.error('No se pudo convertir la imagen a JPEG.'));
        return;
      }

      final bytes = await _blobToBytes(blob);
      if (bytes == null || bytes.isEmpty) {
        finish(WebImageCaptureResult.error('No se pudo leer la imagen.'));
        return;
      }

      final name = _ensureJpgName(file.name);
      finish(WebImageCaptureResult.success(
        bytes: bytes,
        name: name,
        mime: 'image/jpeg',
      ));
    } catch (e) {
      finish(WebImageCaptureResult.error('Error al procesar la imagen: $e'));
    }
  });

  focusSub = html.window.onFocus.listen((_) {
    if (finished) return;
    Future.delayed(const Duration(milliseconds: 300), () {
      if (finished) return;
      final files = input.files;
      if (files == null || files.isEmpty) {
        finish(WebImageCaptureResult.cancelled());
      }
    });
  });

  input.click();
  return completer.future;
}

String _ensureJpgName(String raw) {
  var name = raw.trim().isEmpty ? 'photo' : raw.trim();
  final lower = name.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return name;
  final dot = name.lastIndexOf('.');
  if (dot > 0) {
    name = name.substring(0, dot);
  }
  final ts = DateTime.now().millisecondsSinceEpoch;
  return '${name}_$ts.jpg';
}
