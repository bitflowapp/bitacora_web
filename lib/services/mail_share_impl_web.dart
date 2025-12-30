import 'package:url_launcher/url_launcher.dart';

final class MailShareWeb {
  MailShareWeb._();

  // En Web no se puede adjuntar un archivo local desde la app.
  // Abrimos Gmail/cliente con cuerpo y recordatorio de adjuntar manualmente.
  static Future<void> sendMailWithFile({
    required String filePath,
    String? to,
    String? subject,
    String? body,
  }) async {
    final name = _basename(filePath);
    final uri = Uri.parse(
      'https://mail.google.com/mail/?view=cm&fs=1'
          '${to != null && to.isNotEmpty ? '&to=${Uri.encodeComponent(to)}' : ''}'
          '&su=${Uri.encodeComponent(subject ?? 'Archivo de Gridnote')}'
          '&body=${Uri.encodeComponent(_composeBody(body, name))}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static String _basename(String p) {
    final parts = p.split(RegExp(r'[\\/]+'));
    return parts.isEmpty ? 'archivo.xlsx' : parts.last;
  }

  static String _composeBody(String? body, String name) {
    final base = body == null || body.isEmpty ? '' : '$body\n\n';
    return '${base}Adjuntá manualmente el archivo: $name';
  }
}

// Reexport para el wrapper
Future<void> sendMailWithFile({
  required String filePath,
  String? to,
  String? subject,
  String? body,
}) =>
    MailShareWeb.sendMailWithFile(
      filePath: filePath,
      to: to,
      subject: subject,
      body: body,
    );
