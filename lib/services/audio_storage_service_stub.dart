import 'dart:typed_data';

import 'audio_service.dart';
import 'audio_storage_service.dart';

class AudioStorageServiceImpl implements AudioStorageService {
  @override
  Future<StoredAudio?> saveRecording({
    required String sheetId,
    required String cellKey,
    required String attachmentId,
    required RecordedAudio recording,
  }) async =>
      null;

  @override
  Future<Uint8List?> readAudioBytes(String storageKey) async => null;

  @override
  Future<void> deleteAudio(String storageKey) async {}
}
