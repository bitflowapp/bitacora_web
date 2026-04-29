import 'package:bitacora_web/web/html_compat.dart' as html;
// ignore: uri_does_not_exist
import 'package:bitacora_web/web/js_interop_compat.dart' as js_util;

import 'web_attachment_capabilities.dart';
import 'web_capabilities.dart';

class WebAttachmentCapabilitiesImpl implements WebAttachmentCapabilities {
  static const List<String> _audioCandidates = <String>[
    'audio/mp4;codecs=mp4a.40.2',
    'audio/mp4',
    'audio/aac',
    'audio/webm;codecs=opus',
    'audio/webm',
  ];

  @override
  Future<WebAttachmentCapabilitiesSnapshot> snapshot() async {
    final userAgent = html.window.navigator.userAgent;
    final supportedMimes = <String>[];
    var mediaRecorderAvailable = false;
    try {
      mediaRecorderAvailable =
          js_util.hasProperty(html.window, 'MediaRecorder');
      if (mediaRecorderAvailable) {
        for (final candidate in _audioCandidates) {
          try {
            if (html.MediaRecorder.isTypeSupported(candidate)) {
              supportedMimes.add(candidate);
            }
          } catch (_) {}
        }
      }
    } catch (_) {
      mediaRecorderAvailable = false;
    }

    final storageProbe = await _probeStorage();
    final privateModeLikely = _guessPrivateMode(storageProbe);
    final privateModeReason =
        privateModeLikely ? _privateReason(storageProbe) : 'none';

    return WebAttachmentCapabilitiesSnapshot(
      indexedDbAvailable: WebCapabilities.indexedDbAvailable,
      cacheStorageAvailable: html.window.caches != null,
      serviceWorkerAvailable: WebCapabilities.serviceWorkerSupported,
      isSecureContext: WebCapabilities.isSecureContext,
      isInAppBrowser: WebCapabilities.isInAppBrowser,
      mediaRecorderAvailable: mediaRecorderAvailable,
      supportedAudioMimeTypes: supportedMimes,
      userAgent: userAgent,
      privateModeLikely: privateModeLikely,
      privateModeReason: privateModeReason,
      storagePersisted: storageProbe.persisted,
      storageQuotaBytes: storageProbe.quotaBytes,
      storageUsageBytes: storageProbe.usageBytes,
    );
  }

  bool _guessPrivateMode(_StorageProbe storage) {
    if (!WebCapabilities.indexedDbAvailable) return true;
    final quota = storage.quotaBytes;
    final persisted = storage.persisted;
    if (persisted == false && quota != null && quota > 0) {
      if (quota < 120 * 1024 * 1024) return true;
    }
    if (quota != null && quota > 0) {
      final usage = storage.usageBytes ?? 0;
      if (usage == 0 && quota < 70 * 1024 * 1024) {
        return true;
      }
    }
    return false;
  }

  String _privateReason(_StorageProbe storage) {
    if (!WebCapabilities.indexedDbAvailable) return 'indexeddb_unavailable';
    final quota = storage.quotaBytes;
    if (storage.persisted == false &&
        quota != null &&
        quota < 120 * 1024 * 1024) {
      return 'low_quota_not_persisted';
    }
    if (quota != null && quota < 70 * 1024 * 1024) return 'low_quota';
    return 'heuristic';
  }

  Future<_StorageProbe> _probeStorage() async {
    try {
      final nav = html.window.navigator;
      final storage = js_util.getProperty<Object?>(nav, 'storage');
      if (storage == null) {
        return const _StorageProbe();
      }

      bool? persisted;
      int? quotaBytes;
      int? usageBytes;

      try {
        if (js_util.hasProperty(storage, 'persisted')) {
          final raw = await js_util.promiseToFuture<Object?>(
            js_util.callMethod(storage, 'persisted', const <Object>[]),
          );
          if (raw is bool) persisted = raw;
        }
      } catch (_) {}

      try {
        if (js_util.hasProperty(storage, 'estimate')) {
          final estimate = await js_util.promiseToFuture<Object?>(
            js_util.callMethod(storage, 'estimate', const <Object>[]),
          );
          if (estimate != null) {
            final quota = js_util.getProperty<Object?>(estimate, 'quota');
            final usage = js_util.getProperty<Object?>(estimate, 'usage');
            if (quota is num) quotaBytes = quota.toInt();
            if (usage is num) usageBytes = usage.toInt();
          }
        }
      } catch (_) {}

      return _StorageProbe(
        persisted: persisted,
        quotaBytes: quotaBytes,
        usageBytes: usageBytes,
      );
    } catch (_) {
      return const _StorageProbe();
    }
  }
}

class _StorageProbe {
  const _StorageProbe({
    this.persisted,
    this.quotaBytes,
    this.usageBytes,
  });

  final bool? persisted;
  final int? quotaBytes;
  final int? usageBytes;
}
