// lib/services/auth_service.dart
// Auth basado en Firebase para Web + modo invitado.
// - Web: login real con Google usando FirebaseAuth.signInWithPopup.
// - Mobile (por ahora): entra como invitado (guest).
// - Persiste sesión "reflejada" en SharedPreferences (id/email/etc).
// - Expone userChanges/currentUser para tu AuthGate basado en StreamBuilder.

import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // kIsWeb, ValueNotifier
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
    id: j['id'] as String,
    name: j['name'] as String?,
    email: j['email'] as String?,
    photoUrl: j['photoUrl'] as String?,
  );
}

class AuthService {
  static final AuthService I = AuthService._();

  AuthService._() {
    // Propaga cambios del ValueNotifier al Stream.
    user.addListener(() => _userCtrl.add(user.value));
  }

  static const String _kKey = 'bitacora.auth_user.v1';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSub;

  // Estado actual y errores
  final ValueNotifier<AuthUser?> user = ValueNotifier<AuthUser?>(null);
  final ValueNotifier<String> lastError = ValueNotifier<String>('');

  // Stream + snapshot para AuthGate con StreamBuilder
  final StreamController<AuthUser?> _userCtrl =
  StreamController<AuthUser?>.broadcast();

  Stream<AuthUser?> get userChanges => _userCtrl.stream;
  AuthUser? get currentUser => user.value;

  /// Debe llamarse DESPUÉS de Firebase.initializeApp(...) en main().
  ///
  /// - En Web configura persistencia LOCAL de FirebaseAuth.
  /// - Se suscribe a authStateChanges().
  /// - Restaura invitado desde SharedPreferences si no hay usuario Firebase.
  Future<void> init() async {
    if (kIsWeb) {
      await _auth.setPersistence(Persistence.LOCAL);
    }

    // Escuchar cambios del usuario de Firebase.
    await _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen(
          (User? fbUser) async {
        if (fbUser != null) {
          final AuthUser mapped = AuthUser(
            id: fbUser.uid,
            name: fbUser.displayName,
            email: fbUser.email,
            photoUrl: fbUser.photoURL,
          );
          user.value = mapped;
          await _persist();
        } else {
          // Se cerró sesión en Firebase: limpiamos usuario no-guest.
          if (user.value != null && user.value!.id != 'guest') {
            user.value = null;
            await _persist();
          }
        }
      },
    );

    // Estado inicial:
    final User? fbCurrent = _auth.currentUser;
    if (fbCurrent != null) {
      // Ya hay usuario Firebase (sesión persistida).
      user.value = AuthUser(
        id: fbCurrent.uid,
        name: fbCurrent.displayName,
        email: fbCurrent.email,
        photoUrl: fbCurrent.photoURL,
      );
      await _persist();
    } else {
      // No hay usuario Firebase → intentamos restaurar invitado.
      await _restore();
    }
  }

  Future<void> _restore() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      final String? raw = sp.getString(_kKey);
      if (raw == null || raw.isEmpty) return;
      final Map<String, dynamic> map =
      jsonDecode(raw) as Map<String, dynamic>;
      user.value = AuthUser.fromJson(map);
    } catch (_) {
      // silencioso
    }
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences sp = await SharedPreferences.getInstance();
      final AuthUser? u = user.value;
      if (u == null) {
        await sp.remove(_kKey);
      } else {
        await sp.setString(_kKey, jsonEncode(u.toJson()));
      }
    } catch (_) {
      // silencioso
    }
  }

  /// Login principal:
  /// - Web: Google Sign-In real con FirebaseAuth.
  /// - Mobile: por ahora entra como invitado.
  Future<void> signIn() async {
    lastError.value = '';
    try {
      if (kIsWeb) {
        final GoogleAuthProvider provider = GoogleAuthProvider();
        provider.setCustomParameters(<String, String>{
          'prompt': 'select_account',
        });

        await _auth.signInWithPopup(provider);
        // authStateChanges() se encargará de sincronizar user/_persist().
      } else {
        // En mobile, por ahora, seguimos usando sesión invitado.
        await signInAsGuest();
      }
    } catch (e) {
      lastError.value = 'Error al iniciar sesión: $e';
      rethrow;
    }
  }

  /// Login como invitado (sin Firebase).
  Future<void> signInAsGuest() async {
    user.value = const AuthUser(id: 'guest', name: 'Invitado');
    await _persist();
  }

  /// Cierra la sesión:
  /// - Si hay usuario Firebase, hace signOut() en FirebaseAuth.
  /// - Limpia también la sesión persistida (incluye guest).
  Future<void> signOut() async {
    lastError.value = '';
    try {
      if (_auth.currentUser != null) {
        await _auth.signOut();
      }
    } catch (_) {
      // ignoramos errores de signOut Firebase
    }
    user.value = null;
    await _persist();
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _userCtrl.close();
    user.dispose();
    lastError.dispose();
  }
}
