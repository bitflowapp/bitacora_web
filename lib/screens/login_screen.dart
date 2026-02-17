import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/secure_kv.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _creating = false;
  bool _busy = false;
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

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Completa email y contrasena.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      if (_creating) {
        await AuthService.I.createAccountWithEmail(
          email: email,
          password: pass,
        );
      } else {
        await AuthService.I.signInWithEmail(email: email, password: pass);
      }
      await SecureKv.I.writeString(SecureKvKeys.lastEmail, email);
      await SecureKv.I.writeString(
        SecureKvKeys.lastLoginAt,
        DateTime.now().toUtc().toIso8601String(),
      );

      if (!_bioEnabled && _biometricAvailable) {
        await _offerEnableBiometrics();
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _creating
                ? 'No se pudo crear la cuenta: $e'
                : 'No se pudo iniciar sesion: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.brightness == Brightness.dark
        ? const Color(0xFF0B0D1A)
        : const Color(0xFFFFFFFF);
    final showQuickAccess =
        _bioEnabled && _biometricAvailable && _hasLoggedOnceOnDevice;

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
                        _creating
                            ? 'Crea tu cuenta para empezar.'
                            : 'Inicia sesion para continuar con tu espacio.',
                        style:
                            theme.textTheme.bodyLarge?.copyWith(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      TextField(
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
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: Icon(
                          _creating
                              ? Icons.person_add_alt_1
                              : Icons.login_rounded,
                        ),
                        label:
                            Text(_creating ? 'Crear cuenta' : 'Iniciar sesion'),
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (showQuickAccess) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _quickAccess,
                          icon: const Icon(Icons.fingerprint_rounded),
                          label: Text('Acceso rapido ($_bioLabel)'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            textStyle: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () {
                                setState(() => _creating = !_creating);
                              },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                        child: Text(
                          _creating ? 'Ya tengo cuenta' : 'Crear cuenta',
                        ),
                      ),
                      if (_busy) ...[
                        const SizedBox(height: 12),
                        const Center(child: CircularProgressIndicator()),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        showQuickAccess
                            ? 'Accede rapido con $_bioLabel cuando haya sesion activa.'
                            : 'Inicia sesion con email y contrasena para habilitar acceso rapido.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.74,
                          ),
                          fontSize: 14,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
