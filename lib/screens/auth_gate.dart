// lib/screens/auth_gate.dart
//
// AuthGate BETA (guest-only) — no se queda cargando.
// - Inicializa AuthService con timeout.
// - Si no hay usuario, entra como invitado automáticamente.
// - Si algo falla, igual deja entrar al child (modo demo).
//
// Requiere: lib/services/auth_service.dart (guest-only) con:
//   - AuthService.I.init()
//   - AuthService.I.currentUser
//   - AuthService.I.signInAsGuest()
//   - AuthService.I.user (ValueNotifier<AuthUser?>)

import 'dart:async';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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
        await AuthService.I
            .signInAsGuest()
            .timeout(const Duration(seconds: 2));
      }
    } catch (e) {
      err = '$e';
      // Modo demo: no bloqueamos.
      try {
        if (AuthService.I.currentUser == null) {
          await AuthService.I.signInAsGuest();
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _ready = true;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        // Entra siempre (BETA no bloquea).
        ValueListenableBuilder<AuthUser?>(
          valueListenable: AuthService.I.user,
          builder: (context, u, _) {
            // Si por alguna razón quedó null, seguimos mostrando igual.
            return widget.child;
          },
        ),

        if (_error.trim().isNotEmpty)
          SafeArea(
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
                            .withOpacity(0.92),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                          Theme.of(context).dividerColor.withOpacity(0.5),
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
                              'Auth en modo demo: $_error',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              if (!mounted) return;
                              setState(() => _error = '');
                            },
                            child: const Text('Ocultar'),
                          ),
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: () {
                              if (!mounted) return;
                              setState(() {
                                _ready = false;
                                _error = '';
                              });
                              _boot();
                            },
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
