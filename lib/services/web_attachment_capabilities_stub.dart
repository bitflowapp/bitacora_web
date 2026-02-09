import 'web_attachment_capabilities.dart';

class WebAttachmentCapabilitiesImpl implements WebAttachmentCapabilities {
  @override
  Future<WebAttachmentCapabilitiesSnapshot> snapshot() async {
    return const WebAttachmentCapabilitiesSnapshot(
      indexedDbAvailable: false,
      cacheStorageAvailable: false,
      serviceWorkerAvailable: false,
      isSecureContext: false,
      isInAppBrowser: false,
      mediaRecorderAvailable: false,
      supportedAudioMimeTypes: <String>[],
      userAgent: 'non-web',
      privateModeLikely: false,
      privateModeReason: 'not_web',
    );
  }
}
