// lib/widgets/auth_gate.dart
// Simple auth gate used by legacy flows.

import 'package:flutter/material.dart';

import '../screens/editor_screen.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import '../services/sheet_store.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _initialized = false;
  String? _sheetId;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    await AuthService.I.init();
    final sheetId = await _resolveSheetId();
    if (!mounted) return;
    setState(() {
      _initialized = true;
      _sheetId = sheetId;
    });
  }

  Future<String> _resolveSheetId() async {
    try {
      await SheetStore.init();
      final list = SheetStore.list();
      if (list.isNotEmpty) return list.first.id;
    } catch (_) {
      // Fall through to create a new id.
    }
    return SheetStore.createNew();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_sheetId == null) {
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

        if (user == null) {
          return const LoginScreen();
        }

        return EditorScreen(sheetId: _sheetId!);
      },
    );
  }
}
