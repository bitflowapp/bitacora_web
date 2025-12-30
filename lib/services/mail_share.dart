// lib/services/mail_share.dart
import 'mail_share_io.dart'
if (dart.library.html) 'mail_share_web.dart' as impl;

/// Fachada unificada para enviar correo con archivo adjunto.
/// En IO usa el plugin nativo; en Web abre mailto: con ayuda.
class MailShare {
  static Future<void> sendFile({
    required String filePath,
    required String subject,
    required String body,
  }) async {
    await impl.sendMailWithFile(
      filePath: filePath,
      subject: subject,
      body: body,
    );
  }
}
