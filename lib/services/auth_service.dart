// lib/services/auth_service.dart
//
// AuthService local - sin dependencia de backend externo.
// - Mantiene sesion local persistida en SharedPreferences.
// - Expone ValueNotifier<AuthUser?> user + Stream userChanges.
// - init() es idempotente (no se rompe si se llama varias veces).

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

  static const String _kKey = 'bitflow.auth_user.local.v1';
  static const String _kLegacyKey = 'bitacora.auth_user.guest.v1';

  final ValueNotifier<AuthUser?> user = ValueNotifier<AuthUser?>(null);
  final ValueNotifier<String> lastError = ValueNotifier<String>('');

  final StreamController<AuthUser?> _userCtrl =
      StreamController<AuthUser?>.broadcast();

  Stream<AuthUser?> get userChanges => _userCtrl.stream;
  AuthUser? get currentUser => user.value;

  Future<void>? _initFuture;

  /// Inicializa estado desde SharedPreferences. Idempotente.
  Future<void> init() {
    _initFuture ??= _initImpl();
    return _initFuture!;
  }

  Future<void> _initImpl() async {
    lastError.value = '';
    try {
      await _restore();
      // Si no hay nada persistido, AuthGate crea una sesion local.
    } catch (e) {
      lastError.value = 'Auth init error: $e';
    }
  }

  Future<void> _restore() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    final String? raw = sp.getString(_kKey) ?? sp.getString(_kLegacyKey);
    if (raw == null || raw.trim().isEmpty) return;

    try {
      final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
      user.value = AuthUser.fromJson(map);
      if (sp.getString(_kKey) == null) {
        await sp.setString(_kKey, raw);
      }
    } catch (_) {
      // Si esta corrupto, limpiamos.
      await sp.remove(_kKey);
      await sp.remove(_kLegacyKey);
    }
  }

  Future<void> _persist() async {
    final SharedPreferences sp = await SharedPreferences.getInstance();
    final AuthUser? u = user.value;
    if (u == null) {
      await sp.remove(_kKey);
      await sp.remove(_kLegacyKey);
      return;
    }
    await sp.setString(_kKey, jsonEncode(u.toJson()));
  }

  /// Crea una sesion local anonima para operar offline.
  Future<void> signInAsGuest() async {
    lastError.value = '';
    user.value = const AuthUser(id: 'local', name: 'Usuario local');
    await _persist();
  }

  Future<void> signOut() async {
    lastError.value = '';
    user.value = null;
    await _persist();
  }

  Future<void> dispose() async {
    if (!_userCtrl.isClosed) {
      await _userCtrl.close();
    }
    user.dispose();
    lastError.dispose();
  }
}
