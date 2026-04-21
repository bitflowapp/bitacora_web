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
        if (_error.trim().isNotEmpty && !kReleaseMode)
          _AccessWarningBanner(
            message: _error,
            onDismiss: () {
              if (!mounted) return;
              setState(() => _error = '');
            },
            onRetry: () {
              if (!mounted) return;
              setState(() {
                _ready = false;
                _error = '';
              });
              unawaited(_boot());
            },
          ),
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
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activar Bit Flow',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresa la clave provista para este equipo. La activacion queda guardada localmente.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: _controller,
                      enabled: !_submitting && !widget.expectedKeyMissing,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Clave de licencia',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_message.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    if (widget.restoreWarning.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Aviso tecnico: ${widget.restoreWarning}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: _submitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Activar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: _submitting ? null : widget.onRetry,
                          child: const Text('Reintentar'),
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

class _AccessWarningBanner extends StatelessWidget {
  const _AccessWarningBanner({
    required this.message,
    required this.onDismiss,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onDismiss;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 16,
                      offset: Offset(0, 8),
                      color: Color(0x22000000),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Sesion local recuperada: $message',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton(
                      onPressed: onDismiss,
                      child: const Text('Ocultar'),
                    ),
                    const SizedBox(width: 6),
                    TextButton(
                      onPressed: onRetry,
                      child: const Text('Reintentar'),
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
