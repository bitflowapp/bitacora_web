import 'dart:async';
import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter
import 'dart:typed_data';

import 'diagnostics_log.dart';

enum WebImageCaptureStatus { success, cancelled, blocked, error }

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

  factory WebImageCaptureResult.blocked(String message) =>
      WebImageCaptureResult._(
        status: WebImageCaptureStatus.blocked,
        error: message.trim().isEmpty ? 'Bloqueado' : message.trim(),
      );

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
  StreamSubscription<html.Event>? visibilitySub;
  String? objectUrl;
  Timer? timeoutTimer;
  Timer? pollTimer;
  var finished = false;
  var polling = false;
  var pollTick = 0;

  final ua = html.window.navigator.userAgent;
  final uaLower = ua.toLowerCase();
  final isIOS = uaLower.contains('iphone') ||
      uaLower.contains('ipad') ||
      uaLower.contains('ipod');
  final isSafari = uaLower.contains('safari') &&
      !uaLower.contains('crios') &&
      !uaLower.contains('fxios') &&
      !uaLower.contains('edg') &&
      !uaLower.contains('chrome') &&
      !uaLower.contains('chromium');

  void logStep(String message, {bool ok = true}) {
    DiagnosticsLog.I.record(
      type: DiagnosticActionType.photo,
      ok: ok,
      message: message,
    );
  }

  String _snapshot() {
    final filesLen = input.files?.length ?? 0;
    final valueLen = input.value?.length ?? 0;
    final vis = html.document.visibilityState ?? 'unknown';
    final focus = html.document.activeElement != null;
    return 'vis=$vis focus=$focus valueLen=$valueLen files=$filesLen';
  }

  void finish(WebImageCaptureResult result) {
    if (finished) return;
    final outcomeOk = result.status == WebImageCaptureStatus.success;
    final bytesLen = result.bytes?.length ?? 0;
    logStep(
      'photo:web outcome=${result.status.name} bytes=$bytesLen ${_snapshot()}',
      ok: outcomeOk,
    );
    finished = true;
    try {
      changeSub?.cancel();
      focusSub?.cancel();
      visibilitySub?.cancel();
    } catch (_) {}
    try {
      timeoutTimer?.cancel();
    } catch (_) {}
    try {
      pollTimer?.cancel();
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

  Future<void> processFile(html.File file, {required String source}) async {
    if (finished) return;
    logStep(
      'photo:web files=1 source=$source size=${file.size} name=${file.name} ${_snapshot()}',
    );
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
  }

  void startPolling(String reason) {
    if (finished || polling) return;
    polling = true;
    pollTick = 0;
    logStep('photo:web poll_start reason=$reason ${_snapshot()}');
    pollTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (finished) {
        t.cancel();
        return;
      }
      pollTick += 1;
      final files = input.files;
      final len = files?.length ?? 0;
      logStep('photo:web poll[$pollTick] files=$len ${_snapshot()}');
      if (len > 0 && files != null) {
        t.cancel();
        polling = false;
        unawaited(processFile(files.first, source: 'poll'));
        return;
      }
      if (pollTick * 80 >= 2000) {
        t.cancel();
        polling = false;
        logStep('photo:web poll_timeout ${_snapshot()}', ok: false);
        finish(WebImageCaptureResult.cancelled());
      }
    });
  }

  changeSub = input.onChange.listen((_) async {
    final files = input.files;
    final len = files?.length ?? 0;
    logStep('photo:web change files=$len ${_snapshot()}');
    if (files == null || files.isEmpty) {
      startPolling('change-empty');
      return;
    }
    await processFile(files.first, source: 'change');
  });

  focusSub = html.window.onFocus.listen((_) {
    if (finished) return;
    logStep('photo:web focus ${_snapshot()}');
    final files = input.files;
    if (files != null && files.isNotEmpty) {
      unawaited(processFile(files.first, source: 'focus'));
      return;
    }
    startPolling('focus');
  });

  visibilitySub = html.document.onVisibilityChange.listen((_) {
    if (finished) return;
    final state = html.document.visibilityState;
    if (state == 'visible') {
      logStep('photo:web visible ${_snapshot()}');
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        unawaited(processFile(files.first, source: 'visible'));
        return;
      }
      startPolling('visible');
    }
  });

  timeoutTimer = Timer(const Duration(seconds: 90), () {
    if (finished) return;
    logStep('photo:web timeout', ok: false);
    finish(WebImageCaptureResult.blocked('Tiempo de espera agotado.'));
  });

  logStep(
    'photo:web init ua="$ua" isIOS=$isIOS isSafari=$isSafari capture=$capture ${_snapshot()}',
  );
  try {
    logStep('photo:web click capture=$capture ${_snapshot()}');
    input.click();
  } catch (e) {
    logStep('photo:web click_error $e ${_snapshot()}', ok: false);
    finish(WebImageCaptureResult.blocked('El navegador bloqueo el selector.'));
  }
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
