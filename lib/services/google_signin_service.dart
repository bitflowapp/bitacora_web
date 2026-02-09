// lib/services/google_signin_service.dart
// Thin wrapper kept for legacy imports.

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:google_sign_in/google_sign_in.dart';

import 'google_auth.dart';

class GoogleSigninService {
  GoogleSigninService._();
  static final GoogleSigninService I = GoogleSigninService._();

  ValueNotifier<GoogleSignInAccount?> get user => GoogleAuthService.I.user;
  ValueNotifier<String> get lastError => GoogleAuthService.I.lastError;

  GoogleSignInAccount? get currentUser => GoogleAuthService.I.currentUser;
  bool get isSignedIn => GoogleAuthService.I.isAuthorized;

  Future<void> initOnce({
    List<String> scopes = const ['email', 'profile', 'openid'],
    String? clientId,
    String? serverClientId,
  }) async {
    await GoogleAuthService.I.init(
      clientId: clientId,
      serverClientId: serverClientId,
      bootstrapScopes: scopes,
    );
  }

  Future<GoogleSignInAccount?> signIn() => GoogleAuthService.I.signIn();
  Future<void> signOut() => GoogleAuthService.I.signOut();
  Future<bool> authorizeScopes(List<String> scopes) =>
      GoogleAuthService.I.requestScopes(scopes);
  Future<Map<String, String>?> authorizationHeaders() =>
      GoogleAuthService.I.authorizationHeaders();
  Future<void> dispose() => GoogleAuthService.I.dispose();
}
