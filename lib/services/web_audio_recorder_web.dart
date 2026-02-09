// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'web_audio_recorder.dart';

class WebAudioRecorderImpl implements WebAudioRecorder {
  static const List<String> _preferredMimeTypes = <String>[
    'audio/mp4;codecs=mp4a.40.2',
    'audio/mp4',
    'audio/aac',
    'audio/webm;codecs=opus',
    'audio/webm',
  ];

  @override
  Future<WebAudioRecorderSupport> probeSupport() async {
    final ua = html.window.navigator.userAgent;
    return WebAudioRecorderSupport(
      mediaRecorderAvailable: _hasMediaRecorder(),
      selectedMimeType: pickSupportedMimeType(),
      userAgent: ua,
    );
  }

  @override
  String? pickSupportedMimeType() {
    if (!_hasMediaRecorder()) return null;
    try {
      for (final mime in _preferredMimeTypes) {
        if (html.MediaRecorder.isTypeSupported(mime)) {
          return mime;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _hasMediaRecorder() {
    try {
      // If this static call exists and does not throw, MediaRecorder is present.
      html.MediaRecorder.isTypeSupported('audio/webm');
      return true;
    } catch (_) {
      return false;
    }
  }
}
