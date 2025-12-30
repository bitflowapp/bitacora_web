// lib/services/save_xlsx_io.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String?> saveXlsx(String baseName, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final fileName = baseName.endsWith('.xlsx') ? baseName : '$baseName.xlsx';
  final path = '${dir.path}/$fileName';
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);
  return path;
}
