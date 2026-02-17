import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'build_info.dart';
import 'web_capabilities.dart';

@immutable
class AppUpdateSnapshot {
  const AppUpdateSnapshot({
    required this.requestOk,
    required this.checkedAt,
    required this.sourceUri,
    required this.localVersion,
    required this.localBuildNumber,
    required this.localBuildId,
    required this.remoteVersion,
    required this.remoteBuildId,
    required this.updateAvailable,
    required this.message,
  });

  final bool requestOk;
  final DateTime checkedAt;
  final Uri sourceUri;

  final String localVersion;
  final String localBuildNumber;
  final String localBuildId;

  final String remoteVersion;
  final String remoteBuildId;

  final bool updateAvailable;
  final String message;
}

class AppUpdateService {
  const AppUpdateService({http.Client? client}) : _client = client;

  static const String pagesVersionPath = '/bitacora_web/version.json';
  static const String pagesAssetsVersionPath =
      '/bitacora_web/assets/version.json';

  static const String defaultVersionJsonUrl = String.fromEnvironment(
    'UPDATE_VERSION_URL',
    defaultValue: 'https://marcoluna-nqn.github.io/bitacora_web/version.json',
  );

  static const String androidLatestApkUrl =
      'https://github.com/marcoluna-nqn/bitacora_web/releases/latest/download/BitFlow-android.apk';

  final http.Client? _client;

  Future<AppUpdateSnapshot> checkForUpdates({String? sourceUrl}) async {
    final now = DateTime.now();
    final localInfo = await _readLocalInfo();
    final sourceUris = _resolveVersionUris(sourceUrl);
    final primaryUri = sourceUris.isEmpty
        ? Uri.parse(defaultVersionJsonUrl)
        : sourceUris.first;
    final client = _client ?? http.Client();
    final webOffline = kIsWeb && !WebCapabilities.isOnline;

    if (webOffline) {
      return AppUpdateSnapshot(
        requestOk: false,
        checkedAt: now,
        sourceUri: primaryUri,
        localVersion: localInfo.version,
        localBuildNumber: localInfo.buildNumber,
        localBuildId: localInfo.buildId,
        remoteVersion: '',
        remoteBuildId: '',
        updateAvailable: false,
        message: 'Sin conexion. No se pudo verificar actualizaciones.',
      );
    }

    Object? lastError;
    int? lastStatusCode;
    var attemptedUri = primaryUri;

    try {
      for (final uri in sourceUris) {
        attemptedUri = uri;
        try {
          final response = await client.get(
            uri,
            headers: const <String, String>{
              'Cache-Control': 'no-store',
              'Pragma': 'no-cache',
            },
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode < 200 || response.statusCode >= 300) {
            lastStatusCode = response.statusCode;
            continue;
          }

          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is! Map) {
            lastError = const FormatException('Invalid version payload');
            continue;
          }

          final remoteVersion = _firstNotEmpty(
            <Object?>[
              decoded['appVersion'],
              decoded['version'],
              decoded['semver'],
            ],
          );
          final remoteBuildId = _firstNotEmpty(
            <Object?>[
              decoded['buildId'],
              decoded['build_id'],
              decoded['gitSha'],
              decoded['build'],
            ],
          );

          final updateAvailable = _isUpdateAvailable(
            localVersion: localInfo.version,
            localBuildId: localInfo.buildId,
            remoteVersion: remoteVersion,
            remoteBuildId: remoteBuildId,
          );

          return AppUpdateSnapshot(
            requestOk: true,
            checkedAt: now,
            sourceUri: uri,
            localVersion: localInfo.version,
            localBuildNumber: localInfo.buildNumber,
            localBuildId: localInfo.buildId,
            remoteVersion: remoteVersion,
            remoteBuildId: remoteBuildId,
            updateAvailable: updateAvailable,
            message: updateAvailable
                ? 'Actualizacion disponible.'
                : 'Sin actualizaciones.',
          );
        } on TimeoutException catch (error) {
          lastError = error;
        } catch (error) {
          lastError = error;
        }
      }

      final offlineDetected = _isOfflineError(lastError);
      final failureMessage = offlineDetected
          ? 'Sin conexion. No se pudo verificar actualizaciones.'
          : (lastStatusCode != null
              ? 'No se pudo verificar actualizaciones (HTTP $lastStatusCode).'
              : 'No se pudo consultar version remota.');

      return AppUpdateSnapshot(
        requestOk: false,
        checkedAt: now,
        sourceUri: attemptedUri,
        localVersion: localInfo.version,
        localBuildNumber: localInfo.buildNumber,
        localBuildId: localInfo.buildId,
        remoteVersion: '',
        remoteBuildId: '',
        updateAvailable: false,
        message: failureMessage,
      );
    } on TimeoutException {
      return AppUpdateSnapshot(
        requestOk: false,
        checkedAt: now,
        sourceUri: attemptedUri,
        localVersion: localInfo.version,
        localBuildNumber: localInfo.buildNumber,
        localBuildId: localInfo.buildId,
        remoteVersion: '',
        remoteBuildId: '',
        updateAvailable: false,
        message: 'Sin conexion. No se pudo verificar actualizaciones.',
      );
    } catch (error) {
      return AppUpdateSnapshot(
        requestOk: false,
        checkedAt: now,
        sourceUri: attemptedUri,
        localVersion: localInfo.version,
        localBuildNumber: localInfo.buildNumber,
        localBuildId: localInfo.buildId,
        remoteVersion: '',
        remoteBuildId: '',
        updateAvailable: false,
        message: _isOfflineError(error)
            ? 'Sin conexion. No se pudo verificar actualizaciones.'
            : 'No se pudo consultar version remota.',
      );
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  List<Uri> _resolveVersionUris(String? sourceUrl) {
    final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
    if (sourceUrl != null && sourceUrl.trim().isNotEmpty) {
      return <Uri>[
        _appendCacheBuster(Uri.parse(sourceUrl.trim()), cacheBuster),
      ];
    }

    if (kIsWeb) {
      final candidates = <Uri>[
        Uri.base.resolve(pagesVersionPath),
        Uri.base.resolve(pagesAssetsVersionPath),
        Uri.base.resolve('version.json'),
        Uri.base.resolve('assets/version.json'),
      ];
      final unique = <String, Uri>{};
      for (final uri in candidates) {
        unique[uri.toString()] = _appendCacheBuster(uri, cacheBuster);
      }
      return unique.values.toList(growable: false);
    }

    return <Uri>[
      _appendCacheBuster(Uri.parse(defaultVersionJsonUrl), cacheBuster),
    ];
  }

  Uri _appendCacheBuster(Uri uri, String value) {
    final qp = Map<String, String>.from(uri.queryParameters);
    qp['x'] = value;
    return uri.replace(queryParameters: qp);
  }

  bool _isOfflineError(Object? error) {
    if (error == null) return false;
    if (error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('connection refused') ||
        text.contains('connection reset') ||
        text.contains('network_error') ||
        text.contains('xhr error');
  }

  bool _isUpdateAvailable({
    required String localVersion,
    required String localBuildId,
    required String remoteVersion,
    required String remoteBuildId,
  }) {
    final semverCompare = _compareSemver(remoteVersion, localVersion);
    if (semverCompare != null) {
      if (semverCompare > 0) return true;
      if (semverCompare < 0) return false;
      if (localBuildId.trim().isNotEmpty &&
          remoteBuildId.trim().isNotEmpty &&
          localBuildId.trim() != remoteBuildId.trim()) {
        return true;
      }
      return false;
    }

    if (localVersion.trim().isEmpty && remoteVersion.trim().isNotEmpty) {
      return true;
    }

    if (localBuildId.trim().isNotEmpty && remoteBuildId.trim().isNotEmpty) {
      return localBuildId.trim() != remoteBuildId.trim();
    }
    return false;
  }

  int? _compareSemver(String aRaw, String bRaw) {
    final a = _parseSemver(aRaw);
    final b = _parseSemver(bRaw);
    if (a == null || b == null) return null;
    for (var i = 0; i < 3; i++) {
      if (a[i] > b[i]) return 1;
      if (a[i] < b[i]) return -1;
    }
    return 0;
  }

  List<int>? _parseSemver(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)').firstMatch(text);
    if (match == null) return null;
    final major = int.tryParse(match.group(1) ?? '');
    final minor = int.tryParse(match.group(2) ?? '');
    final patch = int.tryParse(match.group(3) ?? '');
    if (major == null || minor == null || patch == null) return null;
    return <int>[major, minor, patch];
  }

  String _firstNotEmpty(List<Object?> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  Future<_LocalBuildInfo> _readLocalInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = info.version.trim();
      final buildNumber = info.buildNumber.trim();
      return _LocalBuildInfo(
        version: version.isEmpty ? '0.0.0' : version,
        buildNumber: buildNumber,
        buildId: BuildInfo.buildIdLabel,
      );
    } catch (_) {
      return _LocalBuildInfo(
        version: '0.0.0',
        buildNumber: '',
        buildId: BuildInfo.buildIdLabel,
      );
    }
  }
}

class _LocalBuildInfo {
  const _LocalBuildInfo({
    required this.version,
    required this.buildNumber,
    required this.buildId,
  });

  final String version;
  final String buildNumber;
  final String buildId;
}
