import 'audio_service.dart';

class AudioServiceImpl implements AudioService {
  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<void> startAudioRecording({required String sheetId}) =>
      startRecording(sheetId: sheetId);

  @override
  Future<RecordedAudio?> stopAudioRecording() => stopRecording();

  @override
  Future<void> startRecording({required String sheetId}) async {
    throw UnsupportedError('Audio recording not supported on this platform.');
  }

  @override
  Future<RecordedAudio?> stopRecording() async => null;

  @override
  Future<void> dispose() async {}
}
