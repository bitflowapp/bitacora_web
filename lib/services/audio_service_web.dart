import 'dart:typed_data';
import 'dart:html' as html;

import 'package:record/record.dart';

import 'audio_service.dart';

class AudioServiceImpl implements AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  DateTime? _startedAt;

  @override
  Future<bool> isSupported() async {
    try {
      final media = html.window.navigator.mediaDevices;
      if (media == null) return false;
      if (html.MediaRecorder.isTypeSupported('audio/webm')) return true;
      if (html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
        return true;
      }
      if (html.MediaRecorder.isTypeSupported('audio/ogg')) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> startRecording({required String sheetId}) async {
    if (_recording) return;
    final allowed = await hasPermission();
    if (!allowed) {
      throw Exception('Microphone permission denied.');
    }
    await _recorder.start(const RecordConfig(), path: '');
    _recording = true;
    _startedAt = DateTime.now();
  }

  @override
  Future<RecordedAudio?> stopRecording() async {
    if (!_recording) return null;
    final path = await _recorder.stop();
    _recording = false;

    final started = _startedAt;
    _startedAt = null;

    if (path == null || path.trim().isEmpty) return null;

    final bytes = await _readBytes(path.trim());
    if (bytes == null || bytes.isEmpty) return null;

    final duration = started == null
        ? Duration.zero
        : DateTime.now().difference(started);

    final name = _guessFileName(path);
    final mime = _guessMime(path);

    return RecordedAudio(
      fileName: name,
      mime: mime,
      duration: duration,
      bytes: bytes,
    );
  }

  @override
  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
  }

  Future<Uint8List?> _readBytes(String uri) async {
    try {
      if (uri.startsWith('data:')) {
        final data = Uri.parse(uri).data;
        return data?.contentAsBytes();
      }

      final req = await html.HttpRequest.request(
        uri,
        responseType: 'arraybuffer',
      );
      final buf = req.response;
      if (buf is ByteBuffer) {
        return Uint8List.view(buf);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String _guessFileName(String uri) {
    if (uri.contains('.')) {
      final parts = uri.split('/');
      final last = parts.isNotEmpty ? parts.last : '';
      if (last.contains('.')) return last;
    }
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('-', '')
        .replaceAll('.', '');
    return 'audio_$ts.webm';
  }

  String _guessMime(String uri) {
    final lower = uri.toLowerCase();
    if (lower.contains('.wav')) return 'audio/wav';
    if (lower.contains('.ogg')) return 'audio/ogg';
    if (lower.contains('.mp3')) return 'audio/mpeg';
    if (lower.contains('.m4a')) return 'audio/m4a';
    return 'audio/webm';
  }
}
