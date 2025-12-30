// lib/services/google_signin_service.dart
// Versión compatible con google_sign_in: ^6.2.1
// En Web podés pasar --dart-define=GSI_WEB_CLIENT_ID=xxx.apps.googleusercontent.com

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSigninService {
  GoogleSigninService._();
  static final GoogleSigninService I = GoogleSigninService._();

  // Usado solo en Web si lo definís vía --dart-define
  static const String _kWebClientId =
  String.fromEnvironment('GSI_WEB_CLIENT_ID', defaultValue: '');

  late final GoogleSignIn _gsi;
  bool _inited = false;

  final ValueNotifier<GoogleSignInAccount?> user =
  ValueNotifier<GoogleSignInAccount?>(null);
  final ValueNotifier<String> lastError =
  ValueNotifier<String>('');

  StreamSubscription<GoogleSignInAccount?>? _sub;

  GoogleSignInAccount? get currentUser => user.value;
  bool get isSignedIn => user.value != null;

  /// Debe llamarse una vez al inicio (o lo hace signIn() internamente).
  Future<void> initOnce({
    List<String> scopes = const ['email', 'profile', 'openid'],
    String? serverClientId,
  }) async {
    if (_inited) return;

    _gsi = GoogleSignIn(
      scopes: scopes,
      // Solo en Web tiene sentido el clientId aquí
      clientId: kIsWeb && _kWebClientId.isNotEmpty ? _kWebClientId : null,
      serverClientId: serverClientId,
    );

    await _sub?.cancel();
    _sub = _gsi.onCurrentUserChanged.listen(
          (GoogleSignInAccount? acc) {
        user.value = acc;
        lastError.value = '';
      },
      onError: (Object e) {
        user.value = null;
        lastError.value = 'Error de autenticación: $e';
      },
    );

    // Intenta restaurar sesión previa sin UI.
    try {
      final acc = await _gsi.signInSilently();
      user.value = acc;
    } catch (e) {
      lastError.value = 'Error sesión silenciosa: $e';
    }

    _inited = true;
  }

  /// Abre el flujo de login clásico (popup / pantalla nativa).
  Future<GoogleSignInAccount?> signIn() async {
    await initOnce();
    try {
      final acc = await _gsi.signIn();
      user.value = acc;
      lastError.value = '';
      return acc;
    } on Exception catch (e) {
      lastError.value = 'Error al iniciar sesión: $e';
      return null;
    }
  }

  /// Cierra sesión (y revoca si corresponde).
  Future<void> signOut() async {
    if (!_inited) {
      await initOnce();
    }
    try {
      // Revoca en muchos casos
      await _gsi.disconnect();
    } catch (_) {}
    try {
      await _gsi.signOut();
    } catch (_) {}
    user.value = null;
  }

  /// Pide scopes adicionales (Drive, Sheets, etc.).
  Future<bool> authorizeScopes(List<String> scopes) async {
    await initOnce();
    try {
      final ok = await _gsi.requestScopes(scopes);
      return ok;
    } on Exception catch (e) {
      lastError.value = 'Error pidiendo permisos: $e';
      return false;
    }
  }

  /// Headers Authorization para llamar a tu backend con el token de Google.
  Future<Map<String, String>?> authorizationHeaders() async {
    final u = user.value;
    if (u == null) return null;
    try {
      return await u.authHeaders;
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
