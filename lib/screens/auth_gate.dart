import 'dart:async';

import 'package:flutter/material.dart';

import '../services/biometric_auth_service.dart';
import 'login_screen.dart';
import 'biometric_lock_screen.dart';
import '../services/auth_service.dart';
import '../services/runtime_flags.dart';
import '../services/secure_kv.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool _ready = false;
  String _error = '';
  bool _locked = false;
  bool _lockOnOpen = false;
  bool _isMobileBioSupported = false;
  bool _hasPromptedForBiometric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (RuntimeFlags.isAuthRequired) {
      AuthService.I.user.addListener(_onUserChanged);
    }
    _boot();
  }

  @override
  void dispose() {
    if (RuntimeFlags.isAuthRequired) {
      AuthService.I.user.removeListener(_onUserChanged);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!RuntimeFlags.isAuthRequired) return;

    if (state == AppLifecycleState.resumed) {
      _refreshLockState();
      _maybePromptBiometricEnable();
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lockForBackgroundIfNeeded();
    }
  }

  Future<void> _boot() async {
    if (!RuntimeFlags.isAuthRequired) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _error = '';
        _locked = false;
      });
      return;
    }

    String err = '';
    try {
      await AuthService.I.init().timeout(const Duration(seconds: 4));
      await BiometricAuthService.I.init();
      _isMobileBioSupported = BiometricAuthService.I.isSupportedPlatform &&
          BiometricAuthService.I.canCheckBiometrics &&
          BiometricAuthService.I.availableBiometrics.isNotEmpty;
      _lockOnOpen = await SecureKv.I.readBool(SecureKvKeys.bioLockOnOpen);
      await _refreshLockState();
      await _maybePromptBiometricEnable();
    } catch (e) {
      err = '$e';
    }

    if (!mounted) return;
    setState(() {
      _ready = true;
      _error = err;
    });
  }

  void _onUserChanged() {
    _refreshLockState();
    _maybePromptBiometricEnable();
  }

  Future<void> _refreshLockState() async {
    final hasSession = AuthService.I.currentUser != null;
    final shouldLock = hasSession && _lockOnOpen && _isMobileBioSupported;
    if (!mounted) return;
    setState(() {
      if (!hasSession) {
        _locked = false;
        _hasPromptedForBiometric = false;
      } else if (shouldLock) {
        _locked = true;
      } else {
        _locked = false;
      }
    });
  }

  void _lockForBackgroundIfNeeded() {
    final hasSession = AuthService.I.currentUser != null;
    if (!hasSession || !_lockOnOpen || !_isMobileBioSupported) return;
    if (!mounted) return;
    setState(() => _locked = true);
  }

  void _unlockAfterBiometric() {
    if (!mounted) return;
    setState(() => _locked = false);
  }

  Future<void> _usePasswordFallback() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.I.signOut();
      if (!mounted) return;
      setState(() => _locked = false);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo volver al login: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _maybePromptBiometricEnable() async {
    if (!mounted || _hasPromptedForBiometric) return;
    final user = AuthService.I.currentUser;
    if (user == null || !_isMobileBioSupported) return;

    final alreadyEnabled =
        await SecureKv.I.readBool(SecureKvKeys.bioEnabled, defaultValue: false);
    if (alreadyEnabled) return;

    _hasPromptedForBiometric = true;
    if (!mounted) return;

    final bioLabel = BiometricAuthService.I.getBiometricLabel();
    final shouldEnable = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activar acceso rapido',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'Podes usar $bioLabel para entrar y bloquear la app al abrir.',
                  style: const TextStyle(fontSize: 16, height: 1.35),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Activar'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Ahora no'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldEnable != true) return;
    await SecureKv.I.writeBool(SecureKvKeys.bioEnabled, true);
    await SecureKv.I.writeBool(SecureKvKeys.bioLockOnOpen, true);
    _lockOnOpen = true;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Acceso rapido activado con bloqueo al abrir.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!RuntimeFlags.isAuthRequired) {
      return widget.child;
    }

    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        ValueListenableBuilder<AuthUser?>(
          valueListenable: AuthService.I.user,
          builder: (context, user, _) {
            if (user == null) return const LoginScreen();
            if (_locked) {
              return BiometricLockScreen(
                onUnlocked: _unlockAfterBiometric,
                onUsePassword: () {
                  _usePasswordFallback();
                },
                child: widget.child,
              );
            }
            return widget.child;
          },
        ),
        if (_error.trim().isNotEmpty)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 860),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Error de autenticacion: $_error',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            if (!mounted) return;
                            setState(() => _error = '');
                          },
                          child: const Text('Ocultar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
