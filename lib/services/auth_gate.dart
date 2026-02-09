// lib/services/auth_service.dart
//
// AuthService — BETA “guest-only” (sin FirebaseAuth).
// - No depende de firebase_auth.
// - Mantiene sesión invitado en SharedPreferences.
// - Expone userChanges/currentUser + métodos signIn/signInAsGuest/signOut.
// - init() siempre resuelve (timeout defensivo).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'; // ValueNotifier
import 'package:shared_preferences/shared_preferences.dart';

class AuthUser {
  final String id;
  final String? name;
  final String? email;
  final String? photoUrl;

  const AuthUser({
    required this.id,
    this.name,
    this.email,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
      };

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: (j['id'] as String?) ?? 'guest',
        name: j['name'] as String?,
        email: j['email'] as String?,
        photoUrl: j['photoUrl'] as String?,
      );
}

class AuthService {
  static final AuthService I = AuthService._();

  AuthService._() {
    user.addListener(() {
      if (_userCtrl.isClosed) return;
      _userCtrl.add(user.value);
    });
  }

  static const String _kKey = 'bitacora.auth_user.v2';

  // Estado actual + último error
  final ValueNotifier<AuthUser?> user = ValueNotifier<AuthUser?>(null);
  final ValueNotifier<String> lastError = ValueNotifier<String>('');

  // Stream para AuthGate con StreamBuilder
  final StreamController<AuthUser?> _userCtrl =
      StreamController<AuthUser?>.broadcast();

  Stream<AuthUser?> get userChanges => _userCtrl.stream;
  AuthUser? get currentUser => user.value;

  /// Inicializa restaurando sesión (si existe).
  /// Nunca deja el UI colgado: usa timeouts.
  Future<void> init() async {
    lastError.value = '';
    try {
      await _restore().timeout(const Duration(seconds: 2));
    } catch (_) {
      // Si SharedPreferences tarda o falla, seguimos igual.
    }

    // Si no hay sesión, dejamos user=null (AuthGate mostrará LoginScreen).
    if (!_userCtrl.isClosed) {
      _userCtrl.add(user.value);
    }
  }

  Future<void> _restore() async {
    try {
      final sp = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      final raw = sp.getString(_kKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      user.value = AuthUser.fromJson(map);
    } catch (_) {
      // silencioso
    }
  }

  Future<void> _persist() async {
    try {
      final sp = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      final u = user.value;
      if (u == null) {
        await sp.remove(_kKey);
      } else {
        await sp.setString(_kKey, jsonEncode(u.toJson()));
      }
    } catch (_) {
      // silencioso
    }
  }

  /// API “login” general.
  /// En esta beta: siempre invitado (para que no te frene por auth).
  Future<void> signIn() async {
    await signInAsGuest();
  }

  /// Lo que te faltaba: este método existe y compila.
  Future<void> signInAsGuest() async {
    lastError.value = '';
    user.value = const AuthUser(id: 'guest', name: 'Invitado');
    await _persist();
  }

  Future<void> signOut() async {
    lastError.value = '';
    user.value = null;
    await _persist();
  }

  Future<void> dispose() async {
    if (!_userCtrl.isClosed) await _userCtrl.close();
    user.dispose();
    lastError.dispose();
  }
}
