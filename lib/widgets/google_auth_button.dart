// lib/widgets/google_auth_button.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../services/google_auth.dart';

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
      await GoogleAuthService.I.init();

      if (kDebugMode) {
        debugPrint(
          'GoogleAuthButton pressed; user before: ${GoogleAuthService.I.currentUser?.email}',
        );
      }

      final user = GoogleAuthService.I.currentUser;
      if (user == null) {
        await GoogleAuthService.I.signIn();
      } else {
        await GoogleAuthService.I.signOut();
      }

      if (kDebugMode) {
        debugPrint(
          'GoogleAuthButton done; user after: ${GoogleAuthService.I.currentUser?.email}',
        );
      }
    } catch (error, stack) {
      if (kDebugMode) {
        debugPrint('GoogleAuthButton error: $error\n$stack');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auth error: $error'),
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
    return ValueListenableBuilder<GoogleSignInAccount?>(
      valueListenable: GoogleAuthService.I.user,
      builder: (BuildContext context, GoogleSignInAccount? user, _) {
        final bool isLoggedIn = user != null;

        final String label;
        if (_isProcessing) {
          label = 'Procesando...';
        } else {
          label = isLoggedIn ? 'Cerrar sesion' : 'Iniciar sesion';
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
