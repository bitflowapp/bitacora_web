import 'web_attachment_capabilities_stub.dart'
    if (dart.library.html) 'web_attachment_capabilities_web.dart';

class WebAttachmentCapabilitiesSnapshot {
  const WebAttachmentCapabilitiesSnapshot({
    required this.indexedDbAvailable,
    required this.cacheStorageAvailable,
    required this.serviceWorkerAvailable,
    required this.isSecureContext,
    required this.isInAppBrowser,
    required this.mediaRecorderAvailable,
    required this.supportedAudioMimeTypes,
    required this.userAgent,
    required this.privateModeLikely,
    required this.privateModeReason,
    this.storagePersisted,
    this.storageQuotaBytes,
    this.storageUsageBytes,
  });

  final bool indexedDbAvailable;
  final bool cacheStorageAvailable;
  final bool serviceWorkerAvailable;
  final bool isSecureContext;
  final bool isInAppBrowser;
  final bool mediaRecorderAvailable;
  final List<String> supportedAudioMimeTypes;
  final String userAgent;
  final bool privateModeLikely;
  final String privateModeReason;
  final bool? storagePersisted;
  final int? storageQuotaBytes;
  final int? storageUsageBytes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'indexedDbAvailable': indexedDbAvailable,
      'cacheStorageAvailable': cacheStorageAvailable,
      'serviceWorkerAvailable': serviceWorkerAvailable,
      'isSecureContext': isSecureContext,
      'isInAppBrowser': isInAppBrowser,
      'mediaRecorderAvailable': mediaRecorderAvailable,
      'supportedAudioMimeTypes': supportedAudioMimeTypes,
      'userAgent': userAgent,
      'privateModeLikely': privateModeLikely,
      'privateModeReason': privateModeReason,
      if (storagePersisted != null) 'storagePersisted': storagePersisted,
      if (storageQuotaBytes != null) 'storageQuotaBytes': storageQuotaBytes,
      if (storageUsageBytes != null) 'storageUsageBytes': storageUsageBytes,
    };
  }
}

abstract class WebAttachmentCapabilities {
  static WebAttachmentCapabilities get I => WebAttachmentCapabilitiesImpl();

  Future<WebAttachmentCapabilitiesSnapshot> snapshot();
}
