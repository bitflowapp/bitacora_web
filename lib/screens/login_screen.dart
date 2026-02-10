// lib/screens/login_screen.dart
// Pantalla de acceso BETA sin cuenta (guest-only).

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../ui/ui.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _enterAsGuest(BuildContext context) async {
    try {
      await AuthService.I.signInAsGuest();
      // AuthGate escucha userChanges y te saca de acá automáticamente.
    } catch (e) {
      AppToast.show(
        context,
        message: 'No se pudo iniciar como invitado. Intentá nuevamente.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.colors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AppCard(
            padding: const EdgeInsets.all(28),
            shadows: t.shadows.card,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bitácora Web',
                  style: t.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Acceso sin cuenta (BETA)',
                  style: t.text.titleSmall?.copyWith(
                    color: t.colors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Versión de pruebas pensada para cuadrillas y testers.\n\n'
                  'No necesitás cuenta. Los datos se guardan localmente en este dispositivo.',
                  style: t.text.bodyMedium?.copyWith(height: 1.3),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                AppButton(
                  icon: Icons.login_rounded,
                  label: 'Entrar sin cuenta (BETA)',
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.lg,
                  fullWidth: true,
                  onPressed: () => _enterAsGuest(context),
                ),
                const SizedBox(height: 12),
                Text(
                  'Más adelante se van a habilitar cuentas reales y permisos por empresa.',
                  style: t.text.bodySmall?.copyWith(
                    color: t.colors.textSecondary,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
