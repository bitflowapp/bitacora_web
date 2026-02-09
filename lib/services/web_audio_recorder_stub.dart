import 'web_audio_recorder.dart';

class WebAudioRecorderImpl implements WebAudioRecorder {
  @override
  String? pickSupportedMimeType() => null;

  @override
  Future<WebAudioRecorderSupport> probeSupport() async {
    return const WebAudioRecorderSupport(
      mediaRecorderAvailable: false,
      selectedMimeType: null,
      userAgent: '',
    );
  }
}
