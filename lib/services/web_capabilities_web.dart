import 'dart:html' as html; // ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;

class WebCapabilitiesImpl {
  static bool get isSecureContext => html.window.isSecureContext == true;

  static bool get isInAppBrowser {
    final ua = html.window.navigator.userAgent.toLowerCase();
    const markers = <String>[
      'instagram',
      'fbav',
      'fban',
      'fbios',
      'fb_iab',
      'line/',
      'whatsapp',
      'twitter',
      'linkedin',
      'snapchat',
      'pinterest',
      'messenger',
      'kakaotalk',
      'gsa/',
      'wv',
    ];
    for (final m in markers) {
      if (ua.contains(m)) return true;
    }
    return false;
  }

  static bool get geolocationAvailable =>
      html.window.navigator.geolocation != null;

  static bool get mediaRecorderSupported {
    try {
      if (html.MediaRecorder
          .isTypeSupported('audio/mp4;codecs=mp4a.40.2')) {
        return true;
      }
      if (html.MediaRecorder.isTypeSupported('audio/mp4')) return true;
      if (html.MediaRecorder.isTypeSupported('audio/webm')) return true;
      if (html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
        return true;
      }
      if (html.MediaRecorder.isTypeSupported('audio/ogg')) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  static bool get serviceWorkerSupported =>
      html.window.navigator.serviceWorker != null;

  static bool get indexedDbAvailable => html.window.indexedDB != null;

  static bool get cameraAvailable {
    try {
      return html.window.navigator.mediaDevices?.getUserMedia != null;
    } catch (_) {
      return false;
    }
  }

  static bool get imageCaptureSupported {
    try {
      return js_util.hasProperty(html.window, 'ImageCapture');
    } catch (_) {
      return false;
    }
  }
}
