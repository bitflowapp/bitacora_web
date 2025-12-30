// lib/services/google_auth.dart
// Versión compatible con google_sign_in: ^6.2.1
//
// - Usa GoogleSignIn() con scopes y clientId.
// - Usa onCurrentUserChanged + signInSilently().
// - Exponde signIn(), signOut(), requestScopes() y authorizationHeaders().

import 'dart:async';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  GoogleAuthService._();
  static final GoogleAuthService I = GoogleAuthService._();

  late final GoogleSignIn _gsi;
  bool _inited = false;

  final ValueNotifier<GoogleSignInAccount?> user =
  ValueNotifier<GoogleSignInAccount?>(null);
  final ValueNotifier<String> lastError =
  ValueNotifier<String>('');

  StreamSubscription<GoogleSignInAccount?>? _sub;

  GoogleSignInAccount? get currentUser => user.value;
  bool get isAuthorized => user.value != null;

  Future<void> init({
    String? clientId, // en Web: TU_CLIENT_ID_WEB.apps.googleusercontent.com
    List<String> bootstrapScopes = const ['email', 'profile', 'openid'],
  }) async {
    if (_inited) return;

    _gsi = GoogleSignIn(
      clientId: clientId,
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
        lastError.value = 'Error de autenticación: $e';
      },
    );

    // Reintenta sesión silenciosa si el usuario ya había entrado antes.
    try {
      final acc = await _gsi.signInSilently();
      user.value = acc;
    } catch (e) {
      lastError.value = 'Error sesión silenciosa: $e';
    }

    _inited = true;
  }

  Future<void> signIn() async {
    if (!_inited) {
      throw StateError('Llamá antes a GoogleAuthService.I.init(...)');
    }
    try {
      final acc = await _gsi.signIn();
      user.value = acc;
      lastError.value = '';
    } on Exception catch (e) {
      lastError.value = 'Error al iniciar sesión: $e';
    }
  }

  Future<void> signOut() async {
    if (!_inited) return;
    try {
      // disconnect() revoca y cierra sesión en dispositivos.
      await _gsi.disconnect();
    } catch (_) {}
    try {
      await _gsi.signOut();
    } catch (_) {}
    user.value = null;
  }

  /// Pide scopes adicionales (drive, sheets, etc.).
  Future<bool> requestScopes(List<String> scopes) async {
    try {
      final ok = await _gsi.requestScopes(scopes);
      return ok;
    } on Exception catch (e) {
      lastError.value = 'Error pidiendo permisos: $e';
      return false;
    }
  }

  /// Headers Authorization para llamar a tu backend con token de Google.
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
}
