import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricAuthService {
  BiometricAuthService._();

  static final BiometricAuthService I = BiometricAuthService._();

  final LocalAuthentication _auth = LocalAuthentication();

  bool _canCheckBiometrics = false;
  List<BiometricType> _availableBiometrics = const <BiometricType>[];
  bool _initialized = false;

  bool get canCheckBiometrics => _canCheckBiometrics;
  List<BiometricType> get availableBiometrics => _availableBiometrics;

  bool get isSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (!isSupportedPlatform) return;
    try {
      _canCheckBiometrics = await _auth.canCheckBiometrics;
      _availableBiometrics = await _auth.getAvailableBiometrics();
    } catch (_) {
      _canCheckBiometrics = false;
      _availableBiometrics = const <BiometricType>[];
    }
  }

  Future<bool> authenticate(String reason) async {
    if (!isSupportedPlatform) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  String getBiometricLabel() {
    final hasFace = _availableBiometrics.contains(BiometricType.face);
    final hasFingerprint =
        _availableBiometrics.contains(BiometricType.fingerprint);
    final hasStrong = _availableBiometrics.contains(BiometricType.strong);
    final hasWeak = _availableBiometrics.contains(BiometricType.weak);

    if (!kIsWeb && Platform.isIOS) {
      if (hasFace) return 'Face ID';
      if (hasFingerprint) return 'Touch ID';
      return 'Biometria';
    }
    if (!kIsWeb && Platform.isAndroid) {
      if (hasFingerprint || hasStrong || hasWeak) return 'Huella';
      if (hasFace) return 'Biometria';
      return 'Biometria';
    }
    return 'Biometria';
  }
}
