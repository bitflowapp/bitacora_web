import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'premium_config.dart';
import 'runtime_flags.dart';

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

  static const AuthUser demoUser = AuthUser(
    id: 'demo_user',
    name: 'Demo User',
    email: 'demo@bitflow.local',
    isAnonymous: true,
  );

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
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  StreamSubscription<User?>? _authSub;
  Future<void>? _initFuture;
  bool _googleInitDone = false;

  Stream<AuthUser?> get userChanges => _userCtrl.stream;
  AuthUser? get currentUser =>
      RuntimeFlags.isAuthRequired ? user.value : (user.value ?? demoUser);
  bool get isSignedIn =>
      RuntimeFlags.isAuthRequired ? _auth.currentUser != null : true;

  /// Inicializa estado desde SharedPreferences. Idempotente.
  Future<void> init() {
    _initFuture ??= _initImpl();
    return _initFuture!;
  }

  Future<void> _initImpl() async {
    lastError.value = '';
    try {
      if (!RuntimeFlags.isAuthRequired) {
        user.value = demoUser;
        if (!_userCtrl.isClosed) {
          _userCtrl.add(user.value);
        }
        return;
      }

      await _ensureWebPersistence();
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

  Future<void> _ensureWebPersistence() async {
    if (!kIsWeb) return;
    try {
      await _auth.setPersistence(Persistence.LOCAL);
    } catch (_) {
      // Keep default persistence if explicit setup is not available.
    }
  }

  Future<void> _ensureGoogleInit() async {
    if (_googleInitDone || kIsWeb) return;
    await _googleSignIn.initialize();
    _googleInitDone = true;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    lastError.value = '';
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    lastError.value = '';
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider()
          ..addScope('email')
          ..addScope('profile');
        try {
          await _auth.signInWithPopup(provider);
          return;
        } on FirebaseAuthException catch (e) {
          final code = e.code.toLowerCase();
          final shouldFallbackToRedirect = code.contains('popup-blocked') ||
              code.contains('popup-closed-by-user');
          if (!shouldFallbackToRedirect) {
            rethrow;
          }
          await _auth.signInWithRedirect(provider);
          return;
        }
      }

      await _ensureGoogleInit();
      final googleUser = await _googleSignIn.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final idToken = googleUser.authentication.idToken;
      if (idToken == null || idToken.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'missing-google-id-token',
          message: 'No se recibio un token valido de Google.',
        );
      }

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
    } catch (e) {
      lastError.value = 'Google sign-in error: $e';
      rethrow;
    }
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
    if (!RuntimeFlags.isAuthRequired) {
      user.value = demoUser;
      return;
    }

    if (!kIsWeb) {
      try {
        if (_googleInitDone) {
          await _googleSignIn.signOut();
        }
      } catch (_) {}
    }
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
