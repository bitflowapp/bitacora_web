// lib/services/google_auth.dart
// Google sign-in wrapper (web + mobile).

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService I = GoogleAuthService._();

  static const String _kWebClientId =
      String.fromEnvironment('GSI_WEB_CLIENT_ID', defaultValue: '');

  late final GoogleSignIn _gsi;
  bool _inited = false;

  final ValueNotifier<GoogleSignInAccount?> user =
      ValueNotifier<GoogleSignInAccount?>(null);
  final ValueNotifier<String> lastError = ValueNotifier<String>('');

  StreamSubscription<GoogleSignInAccount?>? _sub;

  GoogleSignInAccount? get currentUser => user.value;
  bool get isAuthorized => user.value != null;

  Future<void> init({
    String? clientId,
    String? serverClientId,
    List<String> bootstrapScopes = const ['email', 'profile', 'openid'],
  }) async {
    if (_inited) return;

    final resolvedClientId = _resolveClientId(clientId);
    final resolvedServerClientId = _normalize(serverClientId);

    _gsi = GoogleSignIn(
      clientId: resolvedClientId,
      serverClientId: resolvedServerClientId,
      scopes: bootstrapScopes,
    );

    await _sub?.cancel();
    _sub = _gsi.onCurrentUserChanged.listen(
      (GoogleSignInAccount? account) {
        user.value = account;
        lastError.value = '';
      },
      onError: (Object e) {
        user.value = null;
        lastError.value = 'Auth error: $e';
      },
    );

    try {
      final acc = await _gsi.signInSilently();
      user.value = acc;
    } catch (e) {
      lastError.value = 'Silent sign-in error: $e';
    }

    _inited = true;
  }

  Future<GoogleSignInAccount?> signIn() async {
    if (!_inited) {
      throw StateError('Call GoogleAuthService.I.init(...) first');
    }
    try {
      final acc = await _gsi.signIn();
      user.value = acc;
      lastError.value = '';
      return acc;
    } on Exception catch (e) {
      lastError.value = 'Sign-in error: $e';
      return null;
    }
  }

  Future<void> signOut() async {
    if (!_inited) return;
    try {
      await _gsi.disconnect();
    } catch (_) {}
    try {
      await _gsi.signOut();
    } catch (_) {}
    user.value = null;
  }

  Future<bool> requestScopes(List<String> scopes) async {
    try {
      final ok = await _gsi.requestScopes(scopes);
      return ok;
    } on Exception catch (e) {
      lastError.value = 'Scope request error: $e';
      return false;
    }
  }

  Future<Map<String, String>?> authorizationHeaders() async {
    final acc = user.value;
    if (acc == null) return null;
    try {
      return await acc.authHeaders;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    user.dispose();
    lastError.dispose();
  }

  String? _resolveClientId(String? raw) {
    final normalized = _normalize(raw);
    if (normalized != null) return normalized;
    if (kIsWeb && _kWebClientId.trim().isNotEmpty) {
      return _kWebClientId.trim();
    }
    return null;
  }

  String? _normalize(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
