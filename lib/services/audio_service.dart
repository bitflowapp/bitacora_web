import 'dart:typed_data';

import 'audio_service_stub.dart'
    if (dart.library.io) 'audio_service_io.dart'
    if (dart.library.html) 'audio_service_web.dart';

class RecordedAudio {
  const RecordedAudio({
    required this.fileName,
    required this.mime,
    required this.duration,
    this.bytes,
    this.path,
  });

  final String fileName;
  final String mime;
  final Duration duration;
  final Uint8List? bytes;
  final String? path;
}

abstract class AudioService {
  static AudioService get I => AudioServiceImpl();

  Future<bool> isSupported();
  Future<bool> hasPermission();

  Future<void> startRecording({required String sheetId});
  Future<RecordedAudio?> stopRecording();

  Future<void> dispose();
}
