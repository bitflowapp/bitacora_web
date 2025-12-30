// lib/services/cloud_store.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/table_state.dart';

class CloudStore {
  static const String _baseUrl = 'https://tu-backend.com/api';

  static Future<String?> loadRaw(String sheetId) async {
    final uri = Uri.parse('$_baseUrl/sheets/$sheetId/state');
    try {
      final res = await http.get(uri);
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        return res.body;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> saveState(String sheetId, TableState s) async {
    final uri = Uri.parse('$_baseUrl/sheets/$sheetId/state');
    final body = jsonEncode({
      'headers': s.headers,
      'rows': s.rows,
      'savedAt': s.savedAt.toIso8601String(),
    });
    try {
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
    } catch (_) {}
  }

  static Future<void> uploadXlsx({
    required String sheetId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final uri = Uri.parse('$_baseUrl/sheets/$sheetId/xlsx');
    try {
      final req = http.MultipartRequest('POST', uri)
        ..fields['fileName'] = fileName
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ));
      await req.send();
    } catch (_) {}
  }
}
