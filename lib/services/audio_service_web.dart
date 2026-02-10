import 'dart:async';
import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter
import 'dart:typed_data';

import 'audio_service.dart';
import 'web_audio_recorder.dart';

class AudioServiceImpl implements AudioService {
  bool _recording = false;
  DateTime? _startedAt;

  html.MediaRecorder? _mediaRecorder;
  html.MediaStream? _stream;
  StreamSubscription<html.BlobEvent>? _dataSub;
  final List<html.Blob> _chunks = <html.Blob>[];
  String? _activeMimeType;

  static const html.EventStreamProvider<html.BlobEvent> _dataAvailableEvent =
      html.EventStreamProvider<html.BlobEvent>('dataavailable');
  static const html.EventStreamProvider<html.Event> _stopEvent =
      html.EventStreamProvider<html.Event>('stop');

  @override
  Future<bool> isSupported() async {
    try {
      final media = html.window.navigator.mediaDevices;
      if (media == null) return false;
      final support = await WebAudioRecorder.I.probeSupport();
      return support.isSupported;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      final perms = (html.window.navigator as dynamic).permissions;
      if (perms != null) {
        final status = await perms.query({'name': 'microphone'});
        final state = (status as dynamic).state?.toString() ?? '';
        return state == 'granted';
      }
    } catch (_) {}
    return true;
  }

  @override
  Future<void> startRecording({required String sheetId}) async {
    if (_recording) return;

    final media = html.window.navigator.mediaDevices;
    if (media == null) {
      throw Exception('mic_unsupported: media_devices_unavailable');
    }

    final support = await WebAudioRecorder.I.probeSupport();
    final mime = support.selectedMimeType;
    if (!support.mediaRecorderAvailable || mime == null) {
      throw Exception('mic_unsupported: media_recorder_unavailable');
    }

    html.MediaStream stream;
    try {
      stream = await media.getUserMedia({'audio': true});
    } catch (e) {
      final lower = e.toString().toLowerCase();
      if (lower.contains('notallowed') ||
          lower.contains('permission') ||
          lower.contains('denied')) {
        throw Exception('mic_denied: $e');
      }
      throw Exception('mic_start_failed: $e');
    }

    try {
      final recorder = html.MediaRecorder(stream, {'mimeType': mime});
      _stream = stream;
      _mediaRecorder = recorder;
      _activeMimeType = mime;
      _chunks.clear();

      await _dataSub?.cancel();
      _dataSub = _dataAvailableEvent.forTarget(recorder).listen((event) {
        final data = event.data;
        if (data != null && data.size > 0) {
          _chunks.add(data);
        }
      });

      recorder.start();
      _recording = true;
      _startedAt = DateTime.now();
    } catch (e) {
      _stopStreamTracks(stream);
      _stream = null;
      _mediaRecorder = null;
      _activeMimeType = null;
      final lower = e.toString().toLowerCase();
      if (lower.contains('not supported') || lower.contains('notsupported')) {
        throw Exception('mic_unsupported: $e');
      }
      throw Exception('mic_start_failed: $e');
    }
  }

  @override
  Future<RecordedAudio?> stopRecording() async {
    if (!_recording) return null;
    _recording = false;

    final started = _startedAt;
    _startedAt = null;

    final recorder = _mediaRecorder;
    if (recorder == null) {
      _cleanupAfterStop();
      return null;
    }

    try {
      final stopFuture = _stopEvent
          .forTarget(recorder)
          .first
          .timeout(const Duration(seconds: 4));
      recorder.stop();
      await stopFuture;
    } catch (_) {}

    await _dataSub?.cancel();
    _dataSub = null;

    final mime = recorder.mimeType?.trim().isNotEmpty == true
        ? recorder.mimeType!.trim()
        : (_activeMimeType ?? 'audio/webm');
    final blob = html.Blob(_chunks, mime);
    _chunks.clear();

    final bytes = await _blobToBytes(blob);
    _cleanupAfterStop();

    if (bytes == null || bytes.isEmpty) return null;

    final duration =
        started == null ? Duration.zero : DateTime.now().difference(started);

    return RecordedAudio(
      fileName: _fileNameForMime(mime),
      mime: mime,
      duration: duration,
      bytes: bytes,
    );
  }

  @override
  Future<void> dispose() async {
    try {
      if (_recording) {
        await stopRecording();
      }
    } catch (_) {}

    try {
      await _dataSub?.cancel();
    } catch (_) {}
    _dataSub = null;

    _cleanupAfterStop();
  }

  void _cleanupAfterStop() {
    _mediaRecorder = null;
    _activeMimeType = null;
    _stopStreamTracks(_stream);
    _stream = null;
  }

  void _stopStreamTracks(html.MediaStream? stream) {
    try {
      stream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
  }

  Future<Uint8List?> _blobToBytes(html.Blob blob) async {
    final completer = Completer<Uint8List?>();
    final reader = html.FileReader();
    reader.onLoad.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
      } else {
        completer.complete(null);
      }
    });
    reader.onError.listen((_) => completer.complete(null));
    reader.readAsArrayBuffer(blob);
    return completer.future;
  }

  String _fileNameForMime(String mime) {
    final now = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll('.', '');
    final ext = _extForMime(mime);
    return 'audio_$now$ext';
  }

  String _extForMime(String mime) {
    final lower = mime.toLowerCase();
    if (lower.contains('mp4') ||
        lower.contains('aac') ||
        lower.contains('mp4a')) {
      return '.m4a';
    }
    if (lower.contains('webm')) return '.webm';
    if (lower.contains('ogg')) return '.ogg';
    return '.webm';
  }
}
