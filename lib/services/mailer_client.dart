// lib/services/mailer_client.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

/// Genera un XLSX simple de ejemplo. Reemplazá por tu export real.
Future<Uint8List> buildWorkbookDemo() async {
  final book = xlsio.Workbook();
  final sheet = book.worksheets[0];
  sheet.getRangeByName('A1').setText('Fecha');
  sheet.getRangeByName('B1').setText('Progresiva');
  sheet.getRangeByName('C1').setText('3 electrodos');
  sheet.getRangeByName('D1').setText('4 electrodos');

  sheet.getRangeByName('A2').dateTime = DateTime.now();
  sheet.getRangeByName('B2').setText('KM 12+450');
  sheet.getRangeByName('C2').number = 12.3;
  sheet.getRangeByName('D2').number = 11.7;

  sheet.autoFitColumn(1);
  sheet.autoFitColumn(2);
  sheet.autoFitColumn(3);
  sheet.autoFitColumn(4);

  final bytes = book.saveAsStream();
  book.dispose();
  return Uint8List.fromList(bytes);
}

/// Envía XLSX al microservicio Node (http://host:4000/send-xlsx).
/// baseUrl ej.:
/// - Windows/Web: http://localhost:4000
/// - Android emu: http://10.0.2.2:4000
/// - Dispositivo físico: http://IP_DE_TU_PC:4000
Future<({bool ok, String? id, String? error})> sendXlsxViaMailer({
  required String baseUrl,
  required String to,
  required String fileName,
  required Uint8List xlsxBytes,
}) async {
  final uri = Uri.parse('$baseUrl/send-xlsx');
  final body = jsonEncode({
    'to': to,
    'fileName': fileName,
    'fileBase64': base64Encode(xlsxBytes), // base64 puro
  });

  try {
    final r = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    final bodyText = _decodeUtf8Body(r);

    if (r.statusCode == 200) {
      final j = jsonDecode(bodyText) as Map<String, dynamic>;
      return (ok: true, id: j['id'] as String?, error: null);
    } else {
      // el server devuelve {"error": "..."} en body
      String? msg;
      try {
        msg =
            (jsonDecode(bodyText) as Map<String, dynamic>)['error']?.toString();
      } catch (_) {}
      return (ok: false, id: null, error: msg ?? 'HTTP ${r.statusCode}');
    }
  } catch (e) {
    return (ok: false, id: null, error: e.toString());
  }
}

String _decodeUtf8Body(http.Response response) {
  try {
    return utf8.decode(response.bodyBytes);
  } catch (_) {
    return response.body;
  }
}
