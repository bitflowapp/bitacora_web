import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/feature_flags.dart';
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
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  bool _busy = false;
  bool _showEmailForm = false;
  bool _biometricAvailable = false;
  bool _bioEnabled = false;
  bool _passwordObscured = true;
  bool _isOfferingBiometrics = false;
  String _bioLabel = 'Biometria';

  bool get _authEnabled => kAuthEnabled && RuntimeFlags.isAuthRequired;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricState() async {
    if (!_authEnabled) return;

    try {
      final lastEmail = await SecureKv.I.readString(SecureKvKeys.lastEmail);

      await BiometricAuthService.I.init();

      final available = BiometricAuthService.I.isSupportedPlatform &&
          BiometricAuthService.I.canCheckBiometrics &&
          BiometricAuthService.I.availableBiometrics.isNotEmpty;

      final enabled = await SecureKv.I.readBool(
        SecureKvKeys.bioEnabled,
        defaultValue: false,
      );

      if (!mounted) return;

      final normalizedEmail = (lastEmail ?? '').trim();
      if (normalizedEmail.isNotEmpty) {
        _emailCtrl.text = normalizedEmail;
      }

      setState(() {
        _biometricAvailable = available;
        _bioEnabled = enabled;
        _bioLabel = BiometricAuthService.I.getBiometricLabel();
      });
    } catch (error) {
      debugPrint('LoginScreen._loadBiometricState error: $error');
      if (!mounted) return;
      setState(() {
        _biometricAvailable = false;
        _bioEnabled = false;
        _bioLabel = 'Biometria';
      });
    }
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
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);

    try {
      await AuthService.I.signInWithGoogle();

      final email = (AuthService.I.currentUser?.email ?? '').trim();
      if (email.isNotEmpty) {
        await _saveLastLoginMetadata(email);
      }

      await _maybeOfferEnableBiometrics();
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
          content: Text('No se pudo iniciar con Google. Intenta nuevamente.'),
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
      await _maybeOfferEnableBiometrics();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'user-not-found') {
        final shouldCreate = await _confirmCreateUser(email);
        if (!mounted) return;

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
          content: Text('No se pudo iniciar sesion. Intenta nuevamente.'),
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

      await _maybeOfferEnableBiometrics();
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
          content: Text('No se pudo crear la cuenta. Intenta nuevamente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool?> _confirmCreateUser(String email) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cuenta no encontrada'),
          content: Text(
            'No existe una cuenta para $email. Quieres crearla ahora con esta contrasena?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Crear cuenta'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _maybeOfferEnableBiometrics() async {
    if (!_authEnabled) return;
    if (_isOfferingBiometrics) return;
    if (_bioEnabled || !_biometricAvailable) return;
    if (AuthService.I.currentUser == null) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    _isOfferingBiometrics = true;

    bool lockOnOpen = true;

    try {
      final savedLockOnOpen = await SecureKv.I.readBool(
        SecureKvKeys.bioLockOnOpen,
        defaultValue: true,
      );
      lockOnOpen = savedLockOnOpen;

      if (!mounted) return;

      final shouldEnable = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: true,
        enableDrag: true,
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (modalContext, setModalState) {
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
                        'Usa $_bioLabel para proteger la app y desbloquear mas rapido.',
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
                          'Pedir biometria al abrir o al volver desde background.',
                          style: TextStyle(fontSize: 14),
                        ),
                        onChanged: (value) {
                          setModalState(() => lockOnOpen = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.of(modalContext).pop(true),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Activar'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () => Navigator.of(modalContext).pop(false),
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

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            lockOnOpen
                ? 'Acceso rÃ¡pido activado con bloqueo al abrir.'
                : 'Acceso rÃ¡pido activado.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      debugPrint('LoginScreen._maybeOfferEnableBiometrics error: $error');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo configurar el acceso biomÃ©trico.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _isOfferingBiometrics = false;
    }
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
        return 'El navegador bloqueÃ³ la ventana emergente. Habilitala e intentÃ¡ de nuevo.';
      case 'network-request-failed':
        return 'No hay conexiÃ³n suficiente para iniciar con Google.';
      default:
        return 'No se pudo iniciar con Google (${e.code}).';
    }
  }

  String _emailPasswordErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El email no tiene un formato vÃ¡lido.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email o contraseÃ±a incorrectos.';
      case 'too-many-requests':
        return 'Demasiados intentos. ProbÃ¡ de nuevo en unos minutos.';
      case 'weak-password':
        return 'La contraseÃ±a es demasiado dÃ©bil.';
      case 'email-already-in-use':
        return 'Ese email ya estÃ¡ registrado.';
      case 'network-request-failed':
        return 'No hay conexiÃ³n suficiente para completar el login.';
      default:
        return 'Error de autenticaciÃ³n (${e.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.brightness == Brightness.dark
        ? const Color(0xFF0B0D1A)
        : const Color(0xFFFFFFFF);

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
                  child: AutofillGroup(
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
                          'BitÃ¡cora Web',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _authEnabled
                              ? 'ContinuÃ¡ con Google o usÃ¡ correo y contraseÃ±a.'
                              : 'Modo local-first activo.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (!_authEnabled) ...[
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => context.go('/app'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: shape,
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: const Text('Empezar'),
                          ),
                        ] else ...[
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
                                    setState(() {
                                      _showEmailForm = !_showEmailForm;
                                    });
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
                          AnimatedCrossFade(
                            firstChild: const SizedBox.shrink(),
                            secondChild: Column(
                              children: [
                                const SizedBox(height: 14),
                                TextField(
                                  key: const Key('login-email-input'),
                                  controller: _emailCtrl,
                                  focusNode: _emailFocus,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [AutofillHints.username],
                                  enabled: !_busy,
                                  style: const TextStyle(fontSize: 16),
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    hintText: 'nombre@empresa.com',
                                    border: OutlineInputBorder(),
                                  ),
                                  onSubmitted: (_) {
                                    _passFocus.requestFocus();
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  key: const Key('login-password-input'),
                                  controller: _passCtrl,
                                  focusNode: _passFocus,
                                  enabled: !_busy,
                                  obscureText: _passwordObscured,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  style: const TextStyle(fontSize: 16),
                                  decoration: InputDecoration(
                                    labelText: 'ContraseÃ±a',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      tooltip: _passwordObscured
                                          ? 'Mostrar contraseÃ±a'
                                          : 'Ocultar contraseÃ±a',
                                      onPressed: _busy
                                          ? null
                                          : () {
                                              setState(() {
                                                _passwordObscured =
                                                    !_passwordObscured;
                                              });
                                            },
                                      icon: Icon(
                                        _passwordObscured
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) => _submitEmailPassword(),
                                ),
                                const SizedBox(height: 12),
                                FilledButton(
                                  key: const Key('login-submit'),
                                  onPressed:
                                      _busy ? null : _submitEmailPassword,
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
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.72),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (_biometricAvailable && !_bioEnabled) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    'DespuÃ©s del primer ingreso podÃ©s activar $_bioLabel para proteger la app.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.72),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                            crossFadeState: _showEmailForm
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 180),
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
