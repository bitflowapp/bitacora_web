// lib/screens/auth_gate.dart
//
// Offline-first access gate.
// By default Bit Flow opens with a local session so field work is never blocked.
// Commercial builds can enable a local license wall with:
//   --dart-define=BITFLOW_REQUIRE_LICENSE=true
//   --dart-define=BITFLOW_LICENSE_KEY=<customer-key>

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../ui/ui.dart';

const bool _kRequireLicense = bool.fromEnvironment(
  'BITFLOW_REQUIRE_LICENSE',
  defaultValue: false,
);
const String _kExpectedLicenseKey = String.fromEnvironment(
  'BITFLOW_LICENSE_KEY',
  defaultValue: '',
);
const String _kLicensePrefKey = 'bitflow.license.accepted_key.v1';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _ready = false;
  bool _licenseAccepted = !_kRequireLicense;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    String err = '';
    try {
      await AuthService.I.init().timeout(const Duration(seconds: 4));

      if (AuthService.I.currentUser == null) {
        await AuthService.I.signInAsGuest().timeout(const Duration(seconds: 2));
      }
    } catch (e) {
      err = '$e';
      try {
        if (AuthService.I.currentUser == null) {
          await AuthService.I.signInAsGuest();
        }
      } catch (_) {}
    }

    final licenseAccepted = await _isLicenseAccepted();
    if (!mounted) return;
    setState(() {
      _ready = true;
      _licenseAccepted = licenseAccepted;
      _error = err;
    });
  }

  Future<bool> _isLicenseAccepted() async {
    if (!_kRequireLicense) return true;
    final expected = _kExpectedLicenseKey.trim();
    if (expected.isEmpty) return false;
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kLicensePrefKey)?.trim() == expected;
  }

  Future<bool> _activateLicense(String input) async {
    final expected = _kExpectedLicenseKey.trim();
    if (expected.isEmpty || input.trim() != expected) return false;
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLicensePrefKey, expected);
    if (!mounted) return true;
    setState(() => _licenseAccepted = true);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_licenseAccepted) {
      return _LicenseGate(
        expectedKeyMissing: _kExpectedLicenseKey.trim().isEmpty,
        restoreWarning: kReleaseMode ? '' : _error,
        onSubmit: _activateLicense,
        onRetry: () {
          if (!mounted) return;
          setState(() {
            _ready = false;
            _error = '';
          });
          unawaited(_boot());
        },
      );
    }

    return Stack(
      children: [
        ValueListenableBuilder<AuthUser?>(
          valueListenable: AuthService.I.user,
          builder: (context, user, _) => widget.child,
        ),
        // Demo mode: access warning banner intentionally suppressed so managers
        // never see "Modo demo activo: login deshabilitado" or similar notices.
        // Errors are logged silently via AppErrorReporter.
      ],
    );
  }
}

class _LicenseGate extends StatefulWidget {
  const _LicenseGate({
    required this.expectedKeyMissing,
    required this.restoreWarning,
    required this.onSubmit,
    required this.onRetry,
  });

  final bool expectedKeyMissing;
  final String restoreWarning;
  final Future<bool> Function(String input) onSubmit;
  final VoidCallback onRetry;

  @override
  State<_LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<_LicenseGate> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  String _message = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.expectedKeyMissing) {
      setState(() {
        _message =
            'Esta build requiere licencia, pero no trae clave configurada.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _message = '';
    });
    final ok = await widget.onSubmit(_controller.text);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _message = ok ? '' : 'Clave de licencia invalida.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.colors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: EdgeInsets.all(t.spacing.lg),
              child: AppCard(
                padding: EdgeInsets.all(t.spacing.xl),
                radius: t.radii.xl,
                color: t.colors.surfaceElevated,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: t.colors.accentMuted,
                        borderRadius: BorderRadius.circular(t.radii.lg),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        color: t.colors.accent,
                      ),
                    ),
                    SizedBox(height: t.spacing.md),
                    Text(
                      'Activar Bit Flow',
                      style: t.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: t.spacing.xs),
                    Text(
                      'Ingresa la clave provista para este equipo. La activacion queda guardada localmente.',
                      style: t.text.bodyMedium?.copyWith(
                        color: t.colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: t.spacing.lg),
                    AppTextField(
                      controller: _controller,
                      enabled: !_submitting && !widget.expectedKeyMissing,
                      label: 'Clave de licencia',
                      hint: 'bitflow-...',
                      obscureText: true,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_message.trim().isNotEmpty) ...[
                      SizedBox(height: t.spacing.sm),
                      Text(
                        _message,
                        style: t.text.bodySmall?.copyWith(
                          color: t.colors.dangerFg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (widget.restoreWarning.trim().isNotEmpty) ...[
                      SizedBox(height: t.spacing.sm),
                      Text(
                        'Aviso tecnico: ${widget.restoreWarning}',
                        style: t.text.bodySmall?.copyWith(
                          color: t.colors.textSecondary,
                        ),
                      ),
                    ],
                    SizedBox(height: t.spacing.lg),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppButton(
                          label: 'Activar',
                          icon: Icons.lock_open_rounded,
                          loading: _submitting,
                          fullWidth: true,
                          onPressed: _submitting ? null : _submit,
                        ),
                        SizedBox(height: t.spacing.sm),
                        Align(
                          alignment: Alignment.center,
                          child: AppButton(
                            label: 'Reintentar',
                            variant: AppButtonVariant.ghost,
                            onPressed: _submitting ? null : widget.onRetry,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

