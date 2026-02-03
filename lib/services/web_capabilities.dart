import 'web_capabilities_stub.dart'
    if (dart.library.html) 'web_capabilities_web.dart';

class WebCapabilities {
  static bool get isSecureContext => WebCapabilitiesImpl.isSecureContext;
  static bool get geolocationAvailable => WebCapabilitiesImpl.geolocationAvailable;
  static bool get mediaRecorderSupported => WebCapabilitiesImpl.mediaRecorderSupported;
  static bool get serviceWorkerSupported => WebCapabilitiesImpl.serviceWorkerSupported;
  static bool get indexedDbAvailable => WebCapabilitiesImpl.indexedDbAvailable;
}
