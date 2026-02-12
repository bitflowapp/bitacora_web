import 'package:flutter/material.dart';

import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/widgets/animated_video_background.dart';

class EditorPerfHarnessScreen extends StatelessWidget {
  const EditorPerfHarnessScreen({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;

  static const int _rows = 200;
  static const int _cols = 20;

  @override
  Widget build(BuildContext context) {
    final headers = List<String>.generate(
      _cols,
      (index) => index == _cols - 1 ? 'Photos' : 'Col ${index + 1}',
      growable: false,
    );
    final rows = List<List<String>>.generate(
      _rows,
      (r) => List<String>.generate(
        _cols,
        (c) {
          if (c == _cols - 1) return '';
          if (c == 0) return 'ID-${r + 1}';
          if (c == 1) return 'Fila ${r + 1}';
          return '';
        },
        growable: false,
      ),
      growable: false,
    );

    return AnimatedVideoBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: EditorScreen(
          sheetId: 'perf_harness_200x20',
          initialName: 'Perf Harness 200x20',
          initialHeaders: headers,
          initialRows: rows,
          initialSelectionRow: 0,
          initialSelectionCol: 0,
          perfHarnessEnabled: true,
          isLight: isLight,
          onToggleTheme: onToggleTheme,
        ),
      ),
    );
  }
}
