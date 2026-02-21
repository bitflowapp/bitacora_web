import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/runtime_flags.dart';
import '../services/secure_kv.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _busy = false;
  bool _showEmailForm = false;
  bool _biometricAvailable = false;
  bool _bioEnabled = false;
  bool _hasLoggedOnceOnDevice = false;
  String _bioLabel = 'Biometria';

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricState() async {
    if (!RuntimeFlags.isAuthRequired) return;

    final lastEmail = await SecureKv.I.readString(SecureKvKeys.lastEmail);
    final hasLoginAt = (await SecureKv.I.readString(SecureKvKeys.lastLoginAt))
        ?.trim()
        .isNotEmpty;

    await BiometricAuthService.I.init();
    final available = BiometricAuthService.I.isSupportedPlatform &&
        BiometricAuthService.I.canCheckBiometrics &&
        BiometricAuthService.I.availableBiometrics.isNotEmpty;
    final enabled =
        await SecureKv.I.readBool(SecureKvKeys.bioEnabled, defaultValue: false);

    if (!mounted) return;
    if ((lastEmail ?? '').trim().isNotEmpty) {
      _emailCtrl.text = lastEmail!.trim();
    }
    setState(() {
      _biometricAvailable = available;
      _bioEnabled = enabled;
      _hasLoggedOnceOnDevice = hasLoginAt ?? false;
      _bioLabel = BiometricAuthService.I.getBiometricLabel();
    });
  }

  Future<void> _saveLastLoginMetadata(String email) async {
    await SecureKv.I.writeString(SecureKvKeys.lastEmail, email);
    await SecureKv.I.writeString(
      SecureKvKeys.lastLoginAt,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> _continueWithGoogle() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.I.signInWithGoogle();
      final email = (AuthService.I.currentUser?.email ?? '').trim();
      if (email.isNotEmpty) {
        await _saveLastLoginMetadata(email);
      }
      if (AuthService.I.currentUser != null &&
          !_bioEnabled &&
          _biometricAvailable) {
        await _offerEnableBiometrics();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_googleErrorMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo iniciar con Google: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _submitEmailPassword() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (!_isValidEmail(email) || pass.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ingresa un email valido y una contrasena.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await AuthService.I.signInWithEmail(email: email, password: pass);
      await _saveLastLoginMetadata(email);
      if (!_bioEnabled && _biometricAvailable) {
        await _offerEnableBiometrics();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'user-not-found') {
        final shouldCreate = await _confirmCreateUser(email);
        if (shouldCreate == true) {
          await _createAccount(email, pass);
        }
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(_emailPasswordErrorMessage(e)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo iniciar sesion: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _createAccount(String email, String pass) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.I.createAccountWithEmail(email: email, password: pass);
      await _saveLastLoginMetadata(email);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Cuenta creada. Ya ingresaste.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(_emailPasswordErrorMessage(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo crear la cuenta: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool?> _confirmCreateUser(String email) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cuenta no encontrada'),
          content: Text(
            'No existe una cuenta para $email. Queres crearla ahora con esta contrasena?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Crear cuenta'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _offerEnableBiometrics() async {
    if (!mounted) return;

    bool lockOnOpen = true;
    final shouldEnable = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activar acceso rapido',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Usa $_bioLabel para entrar mas rapido y proteger la app.',
                      style: const TextStyle(fontSize: 16, height: 1.35),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: lockOnOpen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Bloquear al abrir',
                        style: TextStyle(fontSize: 16),
                      ),
                      subtitle: const Text(
                        'Pedir biometria al abrir o volver desde background.',
                        style: TextStyle(fontSize: 16),
                      ),
                      onChanged: (value) {
                        setModalState(() => lockOnOpen = value);
                      },
                    ),
                    const SizedBox(height: 12),
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
      },
    );

    if (shouldEnable != true) return;
    await SecureKv.I.writeBool(SecureKvKeys.bioEnabled, true);
    await SecureKv.I.writeBool(SecureKvKeys.bioLockOnOpen, lockOnOpen);
    if (!mounted) return;
    setState(() => _bioEnabled = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          lockOnOpen
              ? 'Acceso rapido activado con bloqueo al abrir.'
              : 'Acceso rapido activado.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _quickAccess() async {
    if (!_biometricAvailable || _busy) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    final ok = await BiometricAuthService.I.authenticate(
      'Verifica tu identidad para acceso rapido',
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) return;
    if (AuthService.I.isSignedIn) return;

    messenger.showSnackBar(
      const SnackBar(
        content: Text('Inicia sesion una vez para habilitar acceso rapido.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool _isValidEmail(String email) {
    final value = email.trim();
    if (value.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  String _googleErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'popup-closed-by-user':
        return 'Cerraste la ventana de Google antes de completar el login.';
      case 'popup-blocked':
        return 'El navegador bloqueo la ventana emergente. Habilitala e intenta de nuevo.';
      default:
        return 'No se pudo iniciar con Google (${e.code}).';
    }
  }

  String _emailPasswordErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El email no tiene un formato valido.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o contrasena incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. Proba de nuevo en unos minutos.';
      case 'weak-password':
        return 'La contrasena es demasiado debil.';
      case 'email-already-in-use':
        return 'Ese email ya esta registrado.';
      default:
        return 'Error de autenticacion (${e.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.brightness == Brightness.dark
        ? const Color(0xFF0B0D1A)
        : const Color(0xFFFFFFFF);
    final authEnabled = RuntimeFlags.isAuthRequired;
    final showQuickAccess = authEnabled &&
        _bioEnabled &&
        _biometricAvailable &&
        _hasLoggedOnceOnDevice;

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 10,
                color: cardBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 42,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Bitacora Web',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authEnabled
                            ? 'Continua con Google o usa correo y contrasena.'
                            : 'Modo demo activo: el login está deshabilitado temporalmente.',
                        style:
                            theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      if (authEnabled) ...[
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          key: const Key('login-google'),
                          onPressed: _busy ? null : _continueWithGoogle,
                          icon: const _GoogleMark(),
                          label: Text(
                            _busy ? 'Procesando...' : 'Continuar con Google',
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: shape,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          key: const Key('login-email'),
                          onPressed: _busy
                              ? null
                              : () {
                                  setState(
                                      () => _showEmailForm = !_showEmailForm);
                                },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: shape,
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(
                            _showEmailForm
                                ? 'Ocultar correo'
                                : 'Continuar con correo',
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Text(
                            'Accedé desde la portada o /app. Google y correo están ocultos en demo.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      AnimatedCrossFade(
                        firstChild: const SizedBox(height: 0),
                        secondChild: Column(
                          children: [
                            const SizedBox(height: 14),
                            TextField(
                              key: const Key('login-email-input'),
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              enabled: !_busy,
                              style: const TextStyle(fontSize: 16),
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'nombre@empresa.com',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              key: const Key('login-password-input'),
                              controller: _passCtrl,
                              enabled: !_busy,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              style: const TextStyle(fontSize: 16),
                              decoration: const InputDecoration(
                                labelText: 'Contrasena',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              key: const Key('login-submit'),
                              onPressed: _busy ? null : _submitEmailPassword,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: shape,
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('Entrar con correo'),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Si la cuenta no existe, te ofrecemos crearla en el momento.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.72,
                                ),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        crossFadeState: authEnabled && _showEmailForm
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 180),
                      ),
                      if (showQuickAccess) ...[
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _quickAccess,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: Text('Acceso rapido ($_bioLabel)'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: shape,
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        'G',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
