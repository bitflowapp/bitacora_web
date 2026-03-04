import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;

import 'web_capabilities_stub.dart'
    if (dart.library.html) 'web_capabilities_web.dart';

class WebCapabilities {
  @visibleForTesting
  static bool? debugMobileWebUiOverride;

  static bool get isSecureContext => WebCapabilitiesImpl.isSecureContext;
  static bool get isStandalone => WebCapabilitiesImpl.isStandalone;
  static bool get isIosSafari => WebCapabilitiesImpl.isIosSafari;
  static bool get isAndroidChrome => WebCapabilitiesImpl.isAndroidChrome;
  static bool isMobileWebUi({double? shortestSide}) {
    final override = debugMobileWebUiOverride;
    if (override != null) return override;
    if (!kIsWeb) return false;
    return WebCapabilitiesImpl.isMobileWebUi(shortestSide: shortestSide);
  }

  static bool get isInAppBrowser => WebCapabilitiesImpl.isInAppBrowser;
  static bool get isOnline => WebCapabilitiesImpl.isOnline;
  static bool get geolocationAvailable =>
      WebCapabilitiesImpl.geolocationAvailable;
  static bool get mediaRecorderSupported =>
      WebCapabilitiesImpl.mediaRecorderSupported;
  static bool get serviceWorkerSupported =>
      WebCapabilitiesImpl.serviceWorkerSupported;
  static bool get indexedDbAvailable => WebCapabilitiesImpl.indexedDbAvailable;
  static bool get cameraAvailable => WebCapabilitiesImpl.cameraAvailable;
  static bool get imageCaptureSupported =>
      WebCapabilitiesImpl.imageCaptureSupported;
}
