import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'build_info.dart';
import 'force_update_service.dart';
import 'web_capabilities.dart';

class AutoUpdateService {
  AutoUpdateService({
    http.Client? client,
    ForceUpdateService? forceUpdateService,
    Future<SharedPreferences> Function()? preferencesProvider,
    DateTime Function()? nowProvider,
    bool? webOverride,
    bool Function()? isOnline,
    bool allowUnresolvedLocalBuild = false,
  })  : _client = client,
        _forceUpdateService = forceUpdateService ?? ForceUpdateService.I,
        _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance,
        _nowProvider = nowProvider ?? DateTime.now,
        _webOverride = webOverride,
        _isOnline = isOnline ?? (() => WebCapabilities.isOnline),
        _allowUnresolvedLocalBuild = allowUnresolvedLocalBuild;

  static final AutoUpdateService I = AutoUpdateService();

  static const String _attemptBuildKey = 'bitflow.auto_update.last_attempt.v1';
  static const String _attemptTsKey = 'bitflow.auto_update.last_attempt_ts.v1';
  static const Duration _attemptWindow = Duration(minutes: 10);

  final http.Client? _client;
  final ForceUpdateService _forceUpdateService;
  final Future<SharedPreferences> Function() _preferencesProvider;
  final DateTime Function() _nowProvider;
  final bool? _webOverride;
  final bool Function() _isOnline;
  final bool _allowUnresolvedLocalBuild;

  bool _reloadTriggered = false;

  bool get reloadTriggered => _reloadTriggered;

  bool get _isWeb => _webOverride ?? kIsWeb;

  Future<void> maybeAutoUpdateOnStartup({
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    _reloadTriggered = false;
    if (!_isWeb) return;
    if (!_isOnline()) return;
    if (!_allowUnresolvedLocalBuild && _isLocalBuildUnresolved()) return;

    final client = _client ?? http.Client();
    try {
      final now = _nowProvider();
      final remote = await _fetchRemoteVersion(client, timeout);
      if (remote == null) return;

      final remoteToken = _bestSignal(remote);
      if (remoteToken.isEmpty) return;

      if (_matchesLocal(remote)) return;
      if (await _wasAttemptedRecently(remoteToken, now)) return;
      await _rememberAttempt(remoteToken, now);

      _reloadTriggered = true;
      final hasArtifacts = await _forceUpdateService.hasWebCacheArtifacts();
      if (hasArtifacts) {
        await _forceUpdateService.forceUpdate(cacheBustValue: remoteToken);
        return;
      }
      await _forceUpdateService.reloadWithCacheBust(remoteToken);
    } catch (_) {
      // Silent by design: never block startup for update checks.
    } finally {
      if (_client == null) {
        client.close();
      }
    }
  }

  bool _isLocalBuildUnresolved() {
    final buildId = BuildInfo.buildIdLabel.trim();
    final gitSha = BuildInfo.gitSha.trim();
    return (buildId.isEmpty || buildId == 'dev') &&
        (gitSha.isEmpty || gitSha == 'dev');
  }

  Future<Map<String, String>?> _fetchRemoteVersion(
    http.Client client,
    Duration timeout,
  ) async {
    final ts = _nowProvider().millisecondsSinceEpoch.toString();
    final uri = Uri.base.resolve('version.json').replace(
      queryParameters: <String, String>{'ts': ts},
    );
    final response = await client.get(
      uri,
      headers: const <String, String>{
        'Cache-Control': 'no-store',
        'Pragma': 'no-cache',
      },
    ).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final text = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (text.isEmpty) return null;
    final decoded = jsonDecode(text);
    if (decoded is! Map) return null;

    String getSignal(List<String> keys) {
      for (final key in keys) {
        final raw = decoded[key];
        final value = (raw ?? '').toString().trim();
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return <String, String>{
      'buildId': getSignal(const <String>['buildId', 'build_id']),
      'gitSha': getSignal(const <String>['gitSha', 'sha', 'build']),
    };
  }

  bool _matchesLocal(Map<String, String> remote) {
    final remoteBuild = remote['buildId']!.trim();
    final remoteSha = remote['gitSha']!.trim();

    final localBuild = BuildInfo.buildIdLabel.trim();
    final localSha = BuildInfo.gitSha.trim();

    bool eq(String a, String b) {
      if (a.isEmpty || b.isEmpty) return false;
      return a.toLowerCase() == b.toLowerCase();
    }

    return eq(remoteBuild, localBuild) || eq(remoteSha, localSha);
  }

  String _bestSignal(Map<String, String> remote) {
    final build = remote['buildId']!.trim();
    if (build.isNotEmpty) return build;
    return remote['gitSha']!.trim();
  }

  Future<bool> _wasAttemptedRecently(String buildId, DateTime now) async {
    final prefs = await _preferencesProvider();
    final prevBuild = prefs.getString(_attemptBuildKey) ?? '';
    final prevTs = prefs.getInt(_attemptTsKey) ?? 0;
    if (prevBuild.trim() != buildId) return false;
    if (prevTs <= 0) return false;
    final delta = now.millisecondsSinceEpoch - prevTs;
    return delta >= 0 && delta < _attemptWindow.inMilliseconds;
  }

  Future<void> _rememberAttempt(String buildId, DateTime now) async {
    final prefs = await _preferencesProvider();
    await prefs.setString(_attemptBuildKey, buildId);
    await prefs.setInt(_attemptTsKey, now.millisecondsSinceEpoch);
  }
}
