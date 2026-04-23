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
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

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
  StreamSubscription<AuthState>? _remoteAuthSub;

  Stream<AuthUser?> get userChanges => _userCtrl.stream;
  AuthUser? get currentUser => user.value;
  bool get isRemoteBackendConfigured => SupabaseService.I.isConfigured;
  bool get isRemoteAuthenticated => SupabaseService.I.currentUser != null;

  Future<void>? _initFuture;

  /// Inicializa estado desde SharedPreferences. Idempotente.
  Future<void> init() {
    _initFuture ??= _initImpl();
    return _initFuture!;
  }

  Future<void> _initImpl() async {
    lastError.value = '';
    try {
      await SupabaseService.I.init();
      await _restore();
      _restoreSupabaseSession();
      _listenToSupabaseAuth();
      // Si no hay nada persistido, AuthGate crea una sesion local.
    } catch (e) {
      lastError.value = 'Auth init error: $e';
    }
  }

  void _restoreSupabaseSession() {
    final remoteUser = SupabaseService.I.currentUser;
    if (remoteUser == null) return;
    user.value = _fromSupabaseUser(remoteUser);
    unawaited(_persist());
  }

  void _listenToSupabaseAuth() {
    final client = SupabaseService.I.client;
    if (client == null || _remoteAuthSub != null) return;
    _remoteAuthSub = client.auth.onAuthStateChange.listen((event) {
      final remoteUser = event.session?.user;
      if (remoteUser == null) return;
      user.value = _fromSupabaseUser(remoteUser);
      unawaited(_persist());
    });
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

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    lastError.value = '';
    await SupabaseService.I.init();
    final client = SupabaseService.I.client;
    if (client == null) {
      throw StateError('Supabase no esta configurado.');
    }
    final response = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final remoteUser = response.user ?? response.session?.user;
    if (remoteUser == null) {
      throw StateError('Supabase no devolvio usuario autenticado.');
    }
    user.value = _fromSupabaseUser(remoteUser);
    await _persist();
  }

  Future<void> signOut() async {
    lastError.value = '';
    final client = SupabaseService.I.client;
    if (client != null) {
      await client.auth.signOut();
    }
    user.value = null;
    await _persist();
  }

  Future<void> dispose() async {
    await _remoteAuthSub?.cancel();
    if (!_userCtrl.isClosed) {
      await _userCtrl.close();
    }
    user.dispose();
    lastError.dispose();
  }

  AuthUser _fromSupabaseUser(User remoteUser) {
    final metadata = remoteUser.userMetadata ?? const <String, dynamic>{};
    final rawName = metadata['full_name'] ?? metadata['name'];
    return AuthUser(
      id: remoteUser.id,
      email: remoteUser.email,
      name: rawName?.toString(),
      photoUrl: metadata['avatar_url']?.toString(),
    );
  }
}
