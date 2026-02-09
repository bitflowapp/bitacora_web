// lib/export_runner.dart
// Runner para probar la exportación XLSX desde terminal/escritorio.
//
// Ejemplos de uso:
//   flutter run -d windows -t lib/export_runner.dart
//   flutter run -d macos   -t lib/export_runner.dart
//   flutter run -d linux   -t lib/export_runner.dart
//
// En Android/iOS también funciona, pero no cierra la app; solo genera el archivo.

import 'dart:io';

import 'package:flutter/material.dart';
import 'services/xlsx_exporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.now();

  final headers = <String>[
    'Fecha',
    'Progresiva',
    '1m Ω',
    '3m Ω',
    'Obs',
  ];

  final rows = <List<dynamic>>[
    [now, 'PK-001', 12.34, 15.9, 'OK'],
    [now, 'PK-002', 10.0, 11.2, '—'],
  ];

  try {
    final result = await XlsxExporter.export(
      headers: headers,
      rows: rows,
      sheetName: 'Test',
    );

    final pathOrUri = result.savedPathOrUri ?? result.fileName;

    // Log limpio para leer rápido en la terminal.
    // ignore: avoid_print
    print('XLSX generado -> $pathOrUri');

    // En escritorio salimos después de un pequeño delay.
    if (!Platform.isAndroid && !Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      exit(0);
    }
  } catch (e, st) {
    // ignore: avoid_print
    print('Error al exportar XLSX: $e\n$st');
    if (!Platform.isAndroid && !Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      exit(1);
    }
  }

  // En móviles dejamos una app vacía para que el runner no crashee.
  runApp(const SizedBox.shrink());
}
