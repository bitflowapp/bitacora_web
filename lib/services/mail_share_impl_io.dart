import 'dart:io';

import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:url_launcher/url_launcher.dart';

final class MailShareIo {
  MailShareIo._();

  /// IO (Android / iOS / desktop):
  /// 1) flutter_email_sender con adjunto
  /// 2) mailto: con ruta en el cuerpo
  /// 3) share_plus con el archivo
  static Future<void> sendMailWithFile({
    required String filePath,
    String? to,
    String? subject,
    String? body,
  }) async {
    final f = File(filePath);
    if (!await f.exists()) return;

    // 1) Email nativo con adjunto
    try {
      final email = Email(
        recipients: to == null || to.isEmpty ? [] : [to],
        subject: subject ?? '',
        body: body ?? '',
        attachmentPaths: [filePath],
        isHTML: false,
      );
      await FlutterEmailSender.send(email);
      return;
    } catch (_) {
      // sigo con fallback
    }

    // 2) mailto: (sin adjunto; informo ruta en el cuerpo)
    try {
      final uri = Uri(
        scheme: 'mailto',
        path: to ?? '',
        queryParameters: {
          if (subject != null && subject.isNotEmpty) 'subject': subject,
          'body': _joinBody(body, '\n\nAdjunto generado por BitFlow:\n$filePath'),
        },
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // sigo con fallback
    }

    // 3) share sheet del sistema con el archivo
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: body ?? '',
        subject: subject,
      );
    } catch (_) {
      // sin más fallbacks razonables
    }
  }

  static String _joinBody(String? a, String b) {
    if (a == null || a.isEmpty) return b;
    return '$a$b';
  }
}

// Reexport simple para usar como función global
Future<void> sendMailWithFile({
  required String filePath,
  String? to,
  String? subject,
  String? body,
}) =>
    MailShareIo.sendMailWithFile(
      filePath: filePath,
      to: to,
      subject: subject,
      body: body,
    );
