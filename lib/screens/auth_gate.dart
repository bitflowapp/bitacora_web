// lib/screens/auth_gate.dart
// AuthGate para Bitácora Web (BETA sin cuenta).
// - Si NO hay usuario: muestra LoginScreen (Acceso sin cuenta BETA).
// - Si hay usuario: muestra el child (StartPage en tu main).

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    await AuthService.I.init();
    if (!mounted) return;
    setState(() {
      _initialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<AuthUser?>(
      stream: AuthService.I.userChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Sin usuario => pantalla “Acceso sin cuenta (BETA)”
        if (user == null) {
          return const LoginScreen();
        }

        // Con usuario (invitado en esta beta) => StartPage (tu child)
        return widget.child;
      },
    );
  }
}
