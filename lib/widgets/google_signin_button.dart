// Contenedor para el botón de Google (lo dibuja GSI).
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
/* ignore: avoid_web_libraries_in_flutter */
import 'dart:html' as html;
/* ignore: unnecessary_import */
import 'dart:ui' as ui;

import '../services/auth_service.dart';

class GoogleSignInButtonWeb extends StatefulWidget {
  const GoogleSignInButtonWeb({super.key});

  @override
  State<GoogleSignInButtonWeb> createState() => _GoogleSignInButtonWebState();
}

class _GoogleSignInButtonWebState extends State<GoogleSignInButtonWeb> {
  late final String _viewType;
  late final html.DivElement _host;

  @override
  void initState() {
    super.initState();
    _viewType = 'gsi_btn_${DateTime.now().microsecondsSinceEpoch}';
    _host = html.DivElement()
      ..id = _viewType
      ..style.display = 'inline-block'
      ..style.width = '100%'
      ..style.minWidth = '240px'
      ..style.textAlign = 'center';

    if (kIsWeb) {
      // ignore: undefined_prefixed_name
      ui.platformViewRegistry.registerViewFactory(_viewType, (int _) => _host);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        AuthService.I.attachWebButton(_viewType);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.login),
        label: const Text('Google Sign-In (solo Web)'),
      );
    }
    return SizedBox(height: 50, child: HtmlElementView(viewType: _viewType));
  }
}
