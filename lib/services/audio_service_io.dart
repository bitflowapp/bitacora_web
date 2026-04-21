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
  Future<void> startAudioRecording({required String sheetId}) =>
      startRecording(sheetId: sheetId);

  @override
  Future<RecordedAudio?> stopAudioRecording() => stopRecording();

  @override
  Future<void> startRecording({required String sheetId}) async {
    if (_recording) return;

    try {
      final allowed = await hasPermission();
      if (!allowed) {
        throw Exception('Microphone permission denied.');
      }

      final dir = await getApplicationDocumentsDirectory();
      final safeSheet = _sanitize(sheetId);
      final folder = Directory(p.join(dir.path, 'bitflow_audio', safeSheet));
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final now = DateTime.now();
      final stamp =
          '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
      final rand = Random().nextInt(9999).toString().padLeft(4, '0');

      var encoder = AudioEncoder.aacLc;
      var ext = '.m4a';
      var mime = 'audio/m4a';
      final aacSupported = await _recorder.isEncoderSupported(encoder);
      if (!aacSupported) {
        encoder = AudioEncoder.wav;
        ext = '.wav';
        mime = 'audio/wav';
      }

      final name = 'audio_${stamp}_$rand$ext';
      final path = p.join(folder.path, name);

      await _recorder.start(
        RecordConfig(
          encoder: encoder,
          bitRate: encoder == AudioEncoder.wav ? 256000 : 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      _recording = true;
      _startedAt = DateTime.now();
      _currentPath = path;
      _currentName = name;
      _currentMime = mime;
      debugPrint('[AudioService] recording_started path=$path mime=$mime');
    } catch (e, st) {
      _recording = false;
      _startedAt = null;
      _currentPath = null;
      _currentName = null;
      debugPrint('[AudioService] startRecording failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<RecordedAudio?> stopRecording() async {
    if (!_recording) return null;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e, st) {
      _recording = false;
      _startedAt = null;
      debugPrint('[AudioService] stopRecording failed: $e\n$st');
      return null;
    }
    _recording = false;

    final started = _startedAt;
    _startedAt = null;

    final resolved = (path ?? '').trim().isNotEmpty ? path! : _currentPath;
    final name = _currentName ??
        (resolved != null && resolved.isNotEmpty ? p.basename(resolved) : '');

    if (resolved == null || resolved.isEmpty) return null;

    final file = File(resolved);
    if (!await file.exists()) {
      debugPrint('[AudioService] recording_missing path=$resolved');
      return null;
    }
    final size = await file.length();
    if (size <= 0) {
      debugPrint('[AudioService] recording_empty path=$resolved');
      return null;
    }

    final duration =
        started == null ? Duration.zero : DateTime.now().difference(started);
    debugPrint(
      '[AudioService] recording_stopped path=$resolved size=$size durationMs=${duration.inMilliseconds}',
    );

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
