import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'audio_service.dart';

class AudioServiceImpl implements AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _recording = false;
  DateTime? _startedAt;
  String? _currentPath;
  String? _currentName;
  String _currentMime = 'audio/m4a';

  @override
  Future<bool> isSupported() async {
    try {
      final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS;
      final encoder = isDesktop ? AudioEncoder.wav : AudioEncoder.aacLc;
      return await _recorder.isEncoderSupported(encoder);
    } catch (_) {
      return true;
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

    final dir = await getApplicationDocumentsDirectory();
    final safeSheet = _sanitize(sheetId);
    final folder = Directory(p.join(dir.path, 'bitflow_audio', safeSheet));
    if (!folder.existsSync()) {
      folder.createSync(recursive: true);
    }

    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    final rand = Random().nextInt(9999).toString().padLeft(4, '0');

    final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;

    final encoder = isDesktop ? AudioEncoder.wav : AudioEncoder.aacLc;
    final ext = isDesktop ? '.wav' : '.m4a';
    final mime = isDesktop ? 'audio/wav' : 'audio/m4a';

    final name = 'audio_${stamp}_$rand$ext';
    final path = p.join(folder.path, name);

    await _recorder.start(
      RecordConfig(
        encoder: encoder,
        bitRate: isDesktop ? 256000 : 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    _recording = true;
    _startedAt = DateTime.now();
    _currentPath = path;
    _currentName = name;
    _currentMime = mime;
  }

  @override
  Future<RecordedAudio?> stopRecording() async {
    if (!_recording) return null;
    final path = await _recorder.stop();
    _recording = false;

    final started = _startedAt;
    _startedAt = null;

    final resolved = (path ?? '').trim().isNotEmpty ? path! : _currentPath;
    final name = _currentName ??
        (resolved != null && resolved.isNotEmpty ? p.basename(resolved) : '');

    if (resolved == null || resolved.isEmpty) return null;

    final duration = started == null
        ? Duration.zero
        : DateTime.now().difference(started);

    return RecordedAudio(
      fileName: name.isEmpty ? 'audio.m4a' : name,
      mime: _currentMime,
      duration: duration,
      path: resolved,
    );
  }

  @override
  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
  }

  String _sanitize(String raw) {
    final t = raw.trim().isEmpty ? 'sheet' : raw.trim();
    return t.replaceAll(RegExp(r'[\\/:*?"<>|\\s]'), '_');
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
