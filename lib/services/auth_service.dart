import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'premium_config.dart';

class AuthUser {
  final String id;
  final String? name;
  final String? email;
  final String? photoUrl;

  final bool isAnonymous;

  const AuthUser({
    required this.id,
    this.name,
    this.email,
    this.photoUrl,
    this.isAnonymous = false,
  });

  factory AuthUser.fromFirebase(User user) => AuthUser(
        id: user.uid,
        name: user.displayName,
        email: user.email,
        photoUrl: user.photoURL,
        isAnonymous: user.isAnonymous,
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

  final ValueNotifier<AuthUser?> user = ValueNotifier<AuthUser?>(null);
  final ValueNotifier<String> lastError = ValueNotifier<String>('');

  final StreamController<AuthUser?> _userCtrl =
      StreamController<AuthUser?>.broadcast();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<User?>? _authSub;
  Future<void>? _initFuture;

  Stream<AuthUser?> get userChanges => _userCtrl.stream;
  AuthUser? get currentUser => user.value;
  bool get isSignedIn => _auth.currentUser != null;

  /// Inicializa estado desde SharedPreferences. Idempotente.
  Future<void> init() {
    _initFuture ??= _initImpl();
    return _initFuture!;
  }

  Future<void> _initImpl() async {
    lastError.value = '';
    try {
      final current = _auth.currentUser;
      user.value = current == null ? null : AuthUser.fromFirebase(current);
      if (!_userCtrl.isClosed) {
        _userCtrl.add(user.value);
      }
      _authSub = _auth.authStateChanges().listen((firebaseUser) {
        final mapped =
            firebaseUser == null ? null : AuthUser.fromFirebase(firebaseUser);
        user.value = mapped;
      }, onError: (Object e) {
        lastError.value = 'Auth stream error: $e';
      });
    } catch (e) {
      lastError.value = 'Auth init error: $e';
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    lastError.value = '';
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    lastError.value = '';
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUser = credential.user;
    if (firebaseUser != null) {
      await _createTrialProfile(uid: firebaseUser.uid);
    }
    return credential;
  }

  Future<void> _createTrialProfile({required String uid}) async {
    final now = DateTime.now().toUtc();
    final trialDays = PremiumConfig.trialDays;
    final endsAt = now.add(Duration(days: trialDays));
    await _firestore.collection('users').doc(uid).set({
      'isPremium': false,
      'trialStartedAt': FieldValue.serverTimestamp(),
      'trialEndsAt': Timestamp.fromDate(endsAt),
      'premiumSource': 'trial',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// BETA: entra como invitado (sin Firebase).
  Future<void> signInAsGuest() async {
    throw StateError('Guest login is disabled. Use email/password login.');
  }

  Future<void> signIn() async {
    throw StateError('Use signInWithEmail(email, password).');
  }

  Future<void> signOut() async {
    lastError.value = '';
    await _auth.signOut();
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    if (!_userCtrl.isClosed) {
      await _userCtrl.close();
    }
    user.dispose();
    lastError.dispose();
  }
}
