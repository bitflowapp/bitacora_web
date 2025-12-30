// lib/widgets/auth_gate.dart
// Puerta de entrada: si hay usuario -> Editor, si no -> Login BETA.

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/editor_screen.dart'; // Ajustá si tu ruta es distinta

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

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

        // Sin usuario => pantalla de acceso sin cuenta (BETA)
        if (user == null) {
          return const LoginScreen();
        }

        // Con usuario (invitado en esta beta) => editor principal
        return const EditorScreen();
      },
    );
  }
}
