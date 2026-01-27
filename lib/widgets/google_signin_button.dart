// lib/widgets/google_signin_button.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/google_auth.dart';

class GoogleSignInButtonWeb extends StatefulWidget {
  const GoogleSignInButtonWeb({super.key});

  @override
  State<GoogleSignInButtonWeb> createState() => _GoogleSignInButtonWebState();
}

class _GoogleSignInButtonWebState extends State<GoogleSignInButtonWeb> {
  bool _busy = false;

  Future<void> _handlePressed() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await GoogleAuthService.I.init();
      await GoogleAuthService.I.signIn();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('GoogleSignInButton error: $e\n$st');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auth error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      } else {
        _busy = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _busy ? 'Procesando...' : 'Google Sign-In';
    return FilledButton.icon(
      onPressed: _busy ? null : _handlePressed,
      icon: const Icon(Icons.login),
      label: Text(label),
    );
  }
}
