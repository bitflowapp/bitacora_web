import 'dart:typed_data';

import 'audio_storage_service_stub.dart'
    if (dart.library.io) 'audio_storage_service_io.dart'
    if (dart.library.html) 'audio_storage_service_web.dart';

import 'audio_service.dart';

class StoredAudio {
  const StoredAudio({
    required this.storageKey,
    required this.fileName,
    required this.mime,
    required this.bytesLength,
  });

  final String storageKey;
  final String fileName;
  final String mime;
  final int bytesLength;
}

abstract class AudioStorageService {
  static AudioStorageService get I => AudioStorageServiceImpl();

  Future<StoredAudio?> saveRecording({
    required String sheetId,
    required String cellKey,
    required String attachmentId,
    required RecordedAudio recording,
  });

  Future<Uint8List?> readAudioBytes(String storageKey);

  Future<void> deleteAudio(String storageKey);
}
