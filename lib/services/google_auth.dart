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
  static const List<String> _kDefaultScopes = ['email', 'profile', 'openid'];

  late final GoogleSignIn _gsi;
  bool _inited = false;
  List<String> _scopes = _kDefaultScopes;

  final ValueNotifier<GoogleSignInAccount?> user =
      ValueNotifier<GoogleSignInAccount?>(null);
  final ValueNotifier<String> lastError = ValueNotifier<String>('');

  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;

  GoogleSignInAccount? get currentUser => user.value;
  bool get isAuthorized => user.value != null;

  Future<void> init({
    String? clientId,
    String? serverClientId,
    List<String> bootstrapScopes = _kDefaultScopes,
  }) async {
    if (_inited) return;

    final resolvedClientId = _resolveClientId(clientId);
    final resolvedServerClientId = _normalize(serverClientId);

    _scopes = bootstrapScopes;
    _gsi = GoogleSignIn.instance;
    await _gsi.initialize(
      clientId: resolvedClientId,
      serverClientId: resolvedServerClientId,
    );

    await _sub?.cancel();
    _sub = _gsi.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        user.value = event.user;
        lastError.value = '';
      } else if (event is GoogleSignInAuthenticationEventSignOut) {
        user.value = null;
        lastError.value = '';
      }
    }, onError: (Object e) {
      user.value = null;
      lastError.value = 'Auth error: $e';
    });

    try {
      final future = _gsi.attemptLightweightAuthentication();
      if (future != null) {
        final acc = await future;
        if (acc != null) {
          user.value = acc;
          lastError.value = '';
        }
      }
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
      final acc = await _gsi.authenticate(scopeHint: _scopes);
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
      final acc = user.value;
      final client = acc?.authorizationClient ?? _gsi.authorizationClient;
      await client.authorizeScopes(scopes);
      return true;
    } on Exception catch (e) {
      lastError.value = 'Scope request error: $e';
      return false;
    }
  }

  Future<Map<String, String>?> authorizationHeaders() async {
    final acc = user.value;
    if (acc == null) return null;
    try {
      final client = acc.authorizationClient;
      return await client.authorizationHeaders(
        _scopes,
        promptIfNecessary: false,
      );
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
