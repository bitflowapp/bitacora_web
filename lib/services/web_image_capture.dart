import 'dart:async';
import 'package:bitacora_web/web/html_compat.dart' as html;
import 'dart:typed_data';

import 'diagnostics_log.dart';
import 'photo_mime_sniffer.dart';
import 'web_capabilities.dart';
import 'web_file_bytes.dart';

enum WebImageCaptureStatus { success, cancelled, blocked, error }

class WebImageCaptureResult {
  const WebImageCaptureResult._({
    required this.status,
    this.bytes,
    this.name = '',
    this.mime = '',
    this.size,
    this.file,
    this.error,
  });

  final WebImageCaptureStatus status;
  final Uint8List? bytes;
  final String name;
  final String mime;
  final int? size;
  final Object? file; // html.File en web
  final String? error;

  factory WebImageCaptureResult.success({
    required Uint8List bytes,
    required String name,
    required String mime,
    required int size,
    required Object file,
  }) {
    return WebImageCaptureResult._(
      status: WebImageCaptureStatus.success,
      bytes: bytes,
      name: name,
      mime: mime,
      size: size,
      file: file,
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

  html.FileUploadInputElement getPersistentInput() {
    final existing = html.document.getElementById('_bf_photo_input');
    if (existing is html.FileUploadInputElement) return existing;
    final el = html.FileUploadInputElement()
      ..id = '_bf_photo_input'
      ..accept = 'image/*'
      ..multiple = false
      ..style.position = 'fixed'
      ..style.left = '-2000px'
      ..style.top = '-2000px'
      ..style.width = '1px'
      ..style.height = '1px'
      ..style.opacity = '0';
    html.document.body?.append(el);
    return el;
  }

  final input = getPersistentInput();
  // Note: la sola presencia del atributo `capture` (incluso vacío) hace que
  // mobile browsers (iOS Safari, Android Chrome) abran la cámara en lugar
  // de la galería, por eso debe removerse explícitamente cuando capture=false.
  input.removeAttribute('capture');
  if (capture) {
    input.setAttribute('capture', 'environment');
  }
  input.value = '';

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
  final int pollMaxMs = isIOS ? 5000 : 2000;

  void logStep(String message, {bool ok = true}) {
    DiagnosticsLog.I.record(
      type: DiagnosticActionType.photo,
      ok: ok,
      message: message,
    );
  }

  String snapshot() {
    final filesLen = input.files?.length ?? 0;
    final valueLen = input.value?.length ?? 0;
    final vis = html.document.visibilityState;
    final focus = html.document.activeElement != null;
    return 'vis=$vis focus=$focus valueLen=$valueLen files=$filesLen';
  }

  void finish(WebImageCaptureResult result) {
    if (finished) return;
    final outcomeOk = result.status == WebImageCaptureStatus.success;
    final bytesLen = result.bytes?.length ?? 0;
    logStep(
      'photo:web outcome=${result.status.name} bytes=$bytesLen ${snapshot()}',
      ok: outcomeOk,
    );
    DiagnosticsLog.I.updatePhotoAttempt(
      stage: result.status.name,
      bytes: bytesLen > 0 ? bytesLen : null,
      error: result.status == WebImageCaptureStatus.error ||
              result.status == WebImageCaptureStatus.blocked
          ? result.error
          : null,
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
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  String guessMimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.avif')) return 'image/avif';
    return '';
  }

  String fallbackName(String mime) {
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
    final name = file.name.trim().isNotEmpty ? file.name.trim() : '';

    final nameFinal = name.isNotEmpty ? name : fallbackName(fileType);
    logStep(
      'photo:web files=1 source=$source name=$nameFinal type=$fileType size=${file.size} ${snapshot()}',
    );
    DiagnosticsLog.I.updatePhotoAttempt(
      stage: 'file_selected',
      fileName: nameFinal,
      fileSize: file.size,
      fileType: fileType,
      reportedMime: fileType,
      size: file.size,
      visibility: html.document.visibilityState,
      hasFocus: html.document.activeElement != null,
    );

    final readOutcome = await readWebFileBytes(
      file,
      onStage: (stage, data) {
        final bytesLen = (data['bytes'] as num?)?.toInt() ?? 0;
        final rawType = (data['rawType'] ?? '').toString();
        final err = data['error'];
        logStep(
          'photo:web read_$stage name=$nameFinal type=$fileType size=${file.size} bytes=$bytesLen raw=$rawType ${snapshot()}',
          ok: err == null,
        );
        DiagnosticsLog.I.updatePhotoAttempt(
          stage: stage,
          bytes: bytesLen > 0 ? bytesLen : null,
          size: file.size,
          reportedMime: fileType,
          error: err?.toString(),
          stack: data['stack'] as String?,
        );
      },
    );

    var bytes = readOutcome.bytes;
    if ((bytes == null || bytes.isEmpty) && file.size <= 0) {
      DiagnosticsLog.I.updatePhotoAttempt(
        stage: 'bytes_empty_final',
        error: readOutcome.error?.toString() ?? 'empty_bytes',
        stack: readOutcome.stack?.toString(),
        bytes: 0,
        size: file.size,
      );
      finish(WebImageCaptureResult.error('empty_bytes'));
      return;
    }

    final sniffed = sniffMime(bytes ?? Uint8List(0), name: nameFinal);
    final guess = guessMimeFromName(nameFinal);
    final finalMime = sniffed.isNotEmpty
        ? sniffed
        : (fileType.isNotEmpty
            ? fileType
            : (guess.isNotEmpty ? guess : 'application/octet-stream'));

    DiagnosticsLog.I.updatePhotoAttempt(
      stage: 'bytes_ready',
      bytes: bytes?.length,
      size: file.size,
      sniffedMime: sniffed.isNotEmpty ? sniffed : null,
      reportedMime: fileType,
      clearError: true,
      clearStack: true,
    );

    logStep(
        'photo:web bytes=${bytes?.length ?? 0} mime=$finalMime name=$nameFinal size=${file.size} ${snapshot()}');

    finish(WebImageCaptureResult.success(
      bytes: bytes ?? Uint8List(0),
      name: nameFinal,
      mime: finalMime,
      size: file.size,
      file: file,
    ));
  }

  void startPolling(String reason) {
    if (finished || polling) return;
    polling = true;
    pollTick = 0;
    logStep('photo:web poll_start reason=$reason ${snapshot()}');
    pollTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      if (finished) {
        t.cancel();
        return;
      }
      pollTick += 1;
      final files = input.files;
      final len = files?.length ?? 0;
      logStep('photo:web poll[$pollTick] files=$len ${snapshot()}');
      if (len > 0 && files != null) {
        t.cancel();
        polling = false;
        unawaited(processFile(files.first, source: 'poll'));
        return;
      }
      if (pollTick * 100 >= pollMaxMs) {
        t.cancel();
        polling = false;
        logStep('photo:web poll_timeout ${snapshot()}', ok: false);
        finish(WebImageCaptureResult.cancelled());
      }
    });
  }

  changeSub = input.onChange.listen((_) async {
    final files = input.files;
    final len = files?.length ?? 0;
    logStep('photo:web change files=$len ${snapshot()}');
    if (files == null || files.isEmpty) {
      startPolling('change-empty');
      return;
    }
    await processFile(files.first, source: 'change');
  });

  focusSub = html.window.onFocus.listen((_) {
    if (finished) return;
    logStep('photo:web focus ${snapshot()}');
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
      logStep('photo:web visible ${snapshot()}');
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
    'photo:web init ua="$ua" isIOS=$isIOS isSafari=$isSafari secure=${html.window.isSecureContext == true} inApp=${WebCapabilities.isInAppBrowser} gUM=${WebCapabilities.cameraAvailable} capture=$capture ${snapshot()}',
  );
  DiagnosticsLog.I.updatePhotoAttempt(
    stage: 'picker_open',
    ua: ua,
    isIOS: isIOS,
    isSafari: isSafari,
    secureContext: html.window.isSecureContext == true,
    inAppBrowser: WebCapabilities.isInAppBrowser,
    visibility: html.document.visibilityState,
    hasFocus: html.document.activeElement != null,
    reset: true,
    clearError: true,
    clearStack: true,
  );
  try {
    logStep('photo:web click capture=$capture ${snapshot()}');
    input.click();
  } catch (e) {
    logStep('photo:web click_error $e ${snapshot()}', ok: false);
    finish(WebImageCaptureResult.blocked('El navegador bloqueo el selector.'));
  }
  return completer.future;
}
