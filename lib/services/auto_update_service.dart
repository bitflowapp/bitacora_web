import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'build_info.dart';
import 'force_update_service.dart';
import 'web_capabilities.dart';
import 'web_local_storage.dart';

class AutoUpdateService {
  AutoUpdateService({
    http.Client? client,
    ForceUpdateService? forceUpdateService,
    Future<SharedPreferences> Function()? preferencesProvider,
    DateTime Function()? nowProvider,
    bool? webOverride,
    bool Function()? isOnline,
    bool allowUnresolvedLocalBuild = false,
    WebLocalStorage? webLocalStorage,
    String? localGitShaOverride,
    String? localBuildIdOverride,
  })  : _client = client,
        _forceUpdateService = forceUpdateService ?? ForceUpdateService.I,
        _preferencesProvider =
            preferencesProvider ?? SharedPreferences.getInstance,
        _nowProvider = nowProvider ?? DateTime.now,
        _webOverride = webOverride,
        _isOnline = isOnline ?? (() => WebCapabilities.isOnline),
        _allowUnresolvedLocalBuild = allowUnresolvedLocalBuild,
        _webLocalStorage = webLocalStorage ?? WebLocalStorage.I,
        _localGitShaOverride = localGitShaOverride,
        _localBuildIdOverride = localBuildIdOverride;

  static final AutoUpdateService I = AutoUpdateService();

  static const String _attemptBuildKey = 'bitflow.auto_update.last_attempt.v1';
  static const String _attemptTsKey = 'bitflow.auto_update.last_attempt_ts.v1';
  static const String _lastReloadAtKey =
      'bitflow.auto_update.last_reload_at_ms.v1';
  static const Duration _attemptWindow = Duration(minutes: 10);
  static const Duration _reloadWindow = Duration(seconds: 60);

  final http.Client? _client;
  final ForceUpdateService _forceUpdateService;
  final Future<SharedPreferences> Function() _preferencesProvider;
  final DateTime Function() _nowProvider;
  final bool? _webOverride;
  final bool Function() _isOnline;
  final bool _allowUnresolvedLocalBuild;
  final WebLocalStorage _webLocalStorage;
  final String? _localGitShaOverride;
  final String? _localBuildIdOverride;

  bool _reloadTriggered = false;

  bool get reloadTriggered => _reloadTriggered;

  bool get _isWeb => _webOverride ?? kIsWeb;

  Future<void> maybeAutoUpdateOnStartup({
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    _reloadTriggered = false;
    if (!_isWeb) return;
    if (!_isOnline()) return;

    final now = _nowProvider();
    final local = _resolveLocalSignals();
    if (!_allowUnresolvedLocalBuild && !local.isResolved) return;
    if (_isWithinGlobalReloadCooldown(now)) return;

    final client = _client ?? http.Client();
    try {
      final remote = await _fetchRemoteVersion(client, timeout);
      if (remote == null) return;

      final remoteAttemptKey = _remoteAttemptKey(remote);
      if (remoteAttemptKey.isEmpty) return;

      if (_matchesLocal(remote, local)) return;
      if (_isWithinGlobalReloadCooldown(now)) return;
      if (await _wasAttemptedRecently(remoteAttemptKey, now)) return;
      await _rememberAttempt(remoteAttemptKey, now);
      _markReloadAttempt(now);

      final cacheBustToken = _remoteCacheBustToken(
        remote: remote,
        fallback: remoteAttemptKey,
      );
      _reloadTriggered = true;

      final hasArtifacts = await _forceUpdateService.hasWebCacheArtifacts();
      if (hasArtifacts) {
        await _forceUpdateService.forceUpdate(cacheBustValue: cacheBustToken);
        return;
      }
      await _forceUpdateService.reloadWithCacheBust(cacheBustToken);
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[auto-update] startup check skipped: $error');
      }
    } finally {
      if (_client == null) {
        client.close();
      }
    }
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

  _BuildSignals _resolveLocalSignals() {
    var gitSha = _normalizeGitSha(_localGitShaOverride ?? BuildInfo.gitSha);
    final buildId =
        _normalizeBuildId(_localBuildIdOverride ?? BuildInfo.buildId);
    if (gitSha.isEmpty && buildId.isNotEmpty) {
      gitSha = _extractGitShaFromBuildId(buildId);
    }
    return _BuildSignals(gitSha: gitSha, buildId: buildId);
  }

  bool _matchesLocal(Map<String, String> remote, _BuildSignals local) {
    final remoteSha = _normalizeGitSha(remote['gitSha'] ?? '');
    final remoteBuild = _normalizeBuildId(remote['buildId'] ?? '');

    if (remoteSha.isNotEmpty && local.gitSha.isNotEmpty) {
      return _equalsIgnoreCase(remoteSha, local.gitSha);
    }
    if (remoteBuild.isNotEmpty && local.buildId.isNotEmpty) {
      return _equalsIgnoreCase(remoteBuild, local.buildId);
    }
    return false;
  }

  String _remoteAttemptKey(Map<String, String> remote) {
    final build = _normalizeBuildId(remote['buildId'] ?? '');
    if (build.isNotEmpty) return build;
    return _normalizeGitSha(remote['gitSha'] ?? '');
  }

  String _remoteCacheBustToken({
    required Map<String, String> remote,
    required String fallback,
  }) {
    final sha = _normalizeGitSha(remote['gitSha'] ?? '');
    if (sha.isNotEmpty) return sha;
    return fallback;
  }

  bool _isWithinGlobalReloadCooldown(DateTime now) {
    final raw = _webLocalStorage.getItem(_lastReloadAtKey);
    final prev = int.tryParse((raw ?? '').trim()) ?? 0;
    if (prev <= 0) return false;
    final delta = now.millisecondsSinceEpoch - prev;
    return delta >= 0 && delta < _reloadWindow.inMilliseconds;
  }

  void _markReloadAttempt(DateTime now) {
    _webLocalStorage.setItem(
      _lastReloadAtKey,
      now.millisecondsSinceEpoch.toString(),
    );
  }

  String _normalizeBuildId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final lower = value.toLowerCase();
    if (lower == 'dev' || lower == 'unknown' || lower == 'null') return '';
    return value;
  }

  String _normalizeGitSha(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '';
    final lower = value.toLowerCase();
    if (lower == 'dev' || lower == 'unknown' || lower == 'null') return '';
    return value;
  }

  String _extractGitShaFromBuildId(String buildId) {
    final match = RegExp(r'([a-fA-F0-9]{7,40})$').firstMatch(buildId);
    return match == null ? '' : match.group(1)!.toLowerCase();
  }

  bool _equalsIgnoreCase(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    return a.toLowerCase() == b.toLowerCase();
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

class _BuildSignals {
  const _BuildSignals({
    required this.gitSha,
    required this.buildId,
  });

  final String gitSha;
  final String buildId;

  bool get isResolved => gitSha.isNotEmpty || buildId.isNotEmpty;
}
