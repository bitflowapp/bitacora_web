// Helper para leer bytes de archivos en Web con todos los fallbacks posibles.
// Usa arrayBuffer cuando existe, luego FileReader arrayBuffer y por último
// data:URL (base64). Siempre prioriza devolver bytes cuando file.size > 0.

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

class WebFileBytesResult {
  WebFileBytesResult({
    required this.stage,
    this.bytes,
    this.error,
    this.stack,
  });

  final String stage;
  final Uint8List? bytes;
  final Object? error;
  final StackTrace? stack;
}

typedef WebFileBytesLogger = void Function(
    String stage, Map<String, Object?> data);

Uint8List? _bytesFromAny(Object? result) {
  if (result == null) return null;
  if (result is Uint8List) return result;
  if (result is ByteBuffer) return Uint8List.view(result);
  if (result is ByteData) return result.buffer.asUint8List();
  if (result is List<int>) return Uint8List.fromList(result);
  if (result is List<num>) {
    return Uint8List.fromList(result.map((e) => e.toInt()).toList());
  }

  try {
    final maybeBuffer = js_util.getProperty<Object?>(result, 'buffer');
    final byteLength = js_util.getProperty<Object?>(result, 'byteLength');
    if (maybeBuffer is ByteBuffer) {
      final view = Uint8List.view(maybeBuffer);
      if (byteLength is num && byteLength.toInt() < view.lengthInBytes) {
        return Uint8List.view(maybeBuffer, 0, byteLength.toInt());
      }
      return view;
    }
    if (byteLength is num && byteLength.toInt() > 0) {
      final len = byteLength.toInt();
      final out = Uint8List(len);
      for (var i = 0; i < len; i++) {
        final v = js_util.getProperty<Object?>(result, i);
        if (v is num) out[i] = v.toInt();
      }
      return out;
    }
  } catch (_) {}

  return null;
}

Uint8List? _bytesFromDataUrl(Object? raw) {
  if (raw is! String) return null;
  final comma = raw.indexOf(',');
  if (comma < 0 || comma == raw.length - 1) return null;
  final meta = raw.substring(0, comma);
  final payload = raw.substring(comma + 1);
  try {
    if (meta.contains(';base64')) {
      return Uint8List.fromList(base64Decode(payload));
    }
    return Uint8List.fromList(utf8.encode(Uri.decodeFull(payload)));
  } catch (_) {
    return null;
  }
}

Future<WebFileBytesResult> readWebFileBytes(html.File file,
    {WebFileBytesLogger? onStage}) async {
  void logStage(String stage,
      {Uint8List? bytes, Object? raw, Object? error, StackTrace? stack}) {
    onStage?.call(stage, {
      'name': file.name,
      'type': file.type,
      'size': file.size,
      'bytes': bytes?.lengthInBytes ?? 0,
      'rawType': raw?.runtimeType.toString(),
      'error': error?.toString(),
      'stack': stack?.toString(),
    });
  }

  logStage('start');

  try {
    if (js_util.hasProperty(file, 'arrayBuffer')) {
      final promise = js_util.callMethod<Object>(file, 'arrayBuffer', const []);
      final raw = await js_util.promiseToFuture<Object>(promise);
      final bytes = _bytesFromAny(raw);
      logStage('arrayBuffer', bytes: bytes, raw: raw);
      if (bytes != null && bytes.isNotEmpty) {
        return WebFileBytesResult(stage: 'arrayBuffer', bytes: bytes);
      }
    }
  } catch (e, st) {
    logStage('arrayBuffer_error', error: e, stack: st);
  }

  try {
    final reader = html.FileReader();
    final completer = Completer<Uint8List?>();

    reader.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });

    reader.onLoadEnd.first.then((_) {
      if (completer.isCompleted) return;
      completer.complete(_bytesFromAny(reader.result));
    });

    reader.readAsArrayBuffer(file);
    final bytes = await completer.future;
    logStage('filereader_arraybuffer', bytes: bytes, raw: reader.result);
    if (bytes != null && bytes.isNotEmpty) {
      return WebFileBytesResult(stage: 'filereader_arraybuffer', bytes: bytes);
    }
  } catch (e, st) {
    logStage('filereader_arraybuffer_error', error: e, stack: st);
  }

  try {
    final reader = html.FileReader();
    final completer = Completer<Uint8List?>();

    reader.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });

    reader.onLoadEnd.first.then((_) {
      if (completer.isCompleted) return;
      completer.complete(_bytesFromDataUrl(reader.result));
    });

    reader.readAsDataUrl(file);
    final bytes = await completer.future;
    logStage('filereader_dataurl', bytes: bytes, raw: reader.result);
    if (bytes != null && bytes.isNotEmpty) {
      return WebFileBytesResult(stage: 'filereader_dataurl', bytes: bytes);
    }
  } catch (e, st) {
    logStage('filereader_dataurl_error', error: e, stack: st);
    return WebFileBytesResult(
        stage: 'filereader_dataurl_error', error: e, stack: st);
  }

  logStage('bytes_empty');
  return WebFileBytesResult(
    stage: 'bytes_empty',
    bytes: null,
    error: 'empty_bytes',
  );
}
