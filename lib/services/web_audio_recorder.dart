import 'web_audio_recorder_stub.dart'
    if (dart.library.html) 'web_audio_recorder_web.dart';

class WebAudioRecorderSupport {
  const WebAudioRecorderSupport({
    required this.mediaRecorderAvailable,
    required this.selectedMimeType,
    required this.userAgent,
  });

  final bool mediaRecorderAvailable;
  final String? selectedMimeType;
  final String userAgent;

  bool get isSupported => mediaRecorderAvailable && selectedMimeType != null;
}

abstract class WebAudioRecorder {
  static WebAudioRecorder get I => WebAudioRecorderImpl();

  Future<WebAudioRecorderSupport> probeSupport();

  String? pickSupportedMimeType();
}
