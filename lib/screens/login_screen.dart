// lib/screens/login_screen.dart
// Pantalla de acceso BETA sin cuenta (guest-only).

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _enterAsGuest(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await AuthService.I.signInAsGuest();
      // AuthGate escucha userChanges y te saca de acá automáticamente.
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo iniciar como invitado: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final cardBg = theme.brightness == Brightness.dark
        ? const Color(0xFF0B0D1A)
        : const Color(0xFFFFFFFF);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            elevation: 10,
            color: cardBg,
            margin: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: theme.dividerColor.withOpacity(0.35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Bitácora Web',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Acceso sin cuenta (BETA)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Versión de pruebas pensada para cuadrillas y testers.\n\n'
                        'No necesitás cuenta. Los datos se guardan localmente en este dispositivo.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.25),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('Entrar sin cuenta (BETA)'),
                    onPressed: () => _enterAsGuest(context),
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Más adelante se van a habilitar cuentas reales y permisos por empresa.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      height: 1.25,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
