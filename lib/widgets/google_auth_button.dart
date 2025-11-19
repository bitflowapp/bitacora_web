// lib/widgets/google_auth_button.dart
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class GoogleAuthButton extends StatefulWidget {
  const GoogleAuthButton({super.key});

  @override
  State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends State<GoogleAuthButton> {
  bool _isProcessing = false;

  Future<void> _handlePressed() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // ignore: avoid_print
      print('GoogleAuthButton PRESSED; user before: ${AuthService.I.currentUser?.email}');

      final user = AuthService.I.currentUser;
      if (user == null) {
        await AuthService.I.signIn();
      } else {
        await AuthService.I.signOut();
      }

      // ignore: avoid_print
      print('GoogleAuthButton DONE; user after: ${AuthService.I.currentUser?.email}');
    } catch (error, stack) {
      // ignore: avoid_print
      print('Error en GoogleAuthButton: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de autenticación: $error'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService.I.userChanges,
      builder: (BuildContext context, AsyncSnapshot snapshot) {
        final user = snapshot.data;
        final bool isLoggedIn = user != null;

        final String label;
        if (_isProcessing) {
          label = 'Procesando...';
        } else {
          label = isLoggedIn ? 'Cerrar sesión' : 'Iniciar sesión';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: TextButton.icon(
            onPressed: _isProcessing ? null : _handlePressed,
            icon: Icon(
              isLoggedIn ? Icons.logout : Icons.login,
              size: 18,
            ),
            label: Text(
              label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}
