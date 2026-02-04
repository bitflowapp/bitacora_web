import 'dart:async';
import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter
import 'dart:typed_data';

import 'diagnostics_log.dart';
import 'web_capabilities.dart';

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
  final _ = jpegQuality;
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
    try {
      input.remove();
    } catch (_) {}
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  Future<Uint8List?> _readFileBytes(html.File file) async {
    final reader = html.FileReader();
    final done = Completer<Uint8List?>();

    reader.onError.first.then((_) {
      if (!done.isCompleted) done.complete(null);
    });

    reader.onLoadEnd.first.then((_) {
      if (done.isCompleted) return;
      final result = reader.result;
      if (result is ByteBuffer) {
        done.complete(Uint8List.view(result));
        return;
      }
      done.complete(null);
    });

    try {
      reader.readAsArrayBuffer(file);
    } catch (_) {
      if (!done.isCompleted) done.complete(null);
    }

    return done.future;
  }

  String _guessMimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _fallbackName(String mime) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    String ext = 'jpg';
    if (mime.contains('png')) ext = 'png';
    if (mime.contains('webp')) ext = 'webp';
    if (mime.contains('heic')) ext = 'heic';
    if (mime.contains('heif')) ext = 'heif';
    if (mime.contains('gif')) ext = 'gif';
    return 'photo_$ts.$ext';
  }

  Future<void> processFile(html.File file, {required String source}) async {
    if (finished) return;

    final fileType = file.type.trim();
    final fileMime = fileType.isNotEmpty ? fileType : _guessMimeFromName(file.name);
    final name = file.name.trim().isNotEmpty ? file.name.trim() : _fallbackName(fileMime);

    logStep(
      'photo:web files=1 source=$source name=$name type=$fileType size=${file.size} ${_snapshot()}',
    );

    final bytes = await _readFileBytes(file);
    if (bytes == null || bytes.isEmpty) {
      finish(WebImageCaptureResult.error('No se pudo leer la imagen.'));
      return;
    }

    logStep('photo:web bytes=${bytes.length} mime=$fileMime name=$name ${_snapshot()}');

    finish(WebImageCaptureResult.success(
      bytes: bytes,
      name: name,
      mime: fileMime.isEmpty ? 'image/jpeg' : fileMime,
    ));
  }

  void startPolling(String reason) {
    if (finished || polling) return;
    polling = true;
    pollTick = 0;
    logStep('photo:web poll_start reason=$reason ${_snapshot()}');
    pollTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
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
      if (pollTick * 100 >= 2000) {
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
    'photo:web init ua="$ua" isIOS=$isIOS isSafari=$isSafari secure=${html.window.isSecureContext == true} inApp=${WebCapabilities.isInAppBrowser} gUM=${WebCapabilities.cameraAvailable} capture=$capture ${_snapshot()}',
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
