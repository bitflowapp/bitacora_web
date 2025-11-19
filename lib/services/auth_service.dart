// lib/services/auth_service.dart
// Auth mínimo sin Google/Firebase.
// - Solo "invitado" (acceso sin cuenta BETA).
// - Persiste el usuario en SharedPreferences.
// - Mantiene la API: signIn(), signOut(), userChanges, currentUser.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'photoUrl': photoUrl,
  };

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    name: json['name'] as String?,
    email: json['email'] as String?,
    photoUrl: json['photoUrl'] as String?,
  );
}

class AuthService {
  AuthService._();
  static final AuthService I = AuthService._();

  static const _prefsKey = 'auth_user_v1';

  final StreamController<AuthUser?> _ctrl =
  StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;

  /// Stream de cambios de usuario (para AuthGate, etc).
  Stream<AuthUser?> get userChanges => _ctrl.stream;

  /// Usuario actual (puede ser null si no inició sesión).
  AuthUser? get currentUser => _currentUser;

  /// Inicializa la sesión (leer de SharedPreferences).
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      if (stored != null) {
        final map = jsonDecode(stored) as Map<String, dynamic>;
        _currentUser = AuthUser.fromJson(map);
      }
    } catch (e, st) {
      debugPrint('AuthService.init error: $e\n$st');
      _currentUser = null;
    }

    _ctrl.add(_currentUser);
  }

  /// Inicia sesión como "invitado" (acceso sin cuenta BETA).
  ///
  /// Mantiene la firma `signIn()` para no romper código existente.
  Future<void> signIn() async {
    final user = AuthUser(
      id: 'guest',
      name: 'Invitado Bitácora',
      email: null,
      photoUrl: null,
    );

    _currentUser = user;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(user.toJson()));
    } catch (e, st) {
      debugPrint('AuthService.signIn save error: $e\n$st');
    }

    _ctrl.add(_currentUser);
  }

  /// Cierra sesión y limpia el usuario guardado.
  Future<void> signOut() async {
    _currentUser = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e, st) {
      debugPrint('AuthService.signOut error: $e\n$st');
    }

    _ctrl.add(_currentUser);
  }

  void dispose() {
    _ctrl.close();
  }
}
