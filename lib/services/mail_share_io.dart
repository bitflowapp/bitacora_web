import 'dart:io';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Envía por correo con fallbacks:
/// 1) flutter_email_sender  2) mailto:  3) share_plus
Future<void> sendMailWithFile({
  required String filePath,
  String? to,
  String? subject,
  String? body,
}) async {
  if (!await File(filePath).exists()) return;

  try {
    final email = Email(
      body: body ?? '',
      subject: subject ?? 'Exportación Gridnote',
      recipients: to == null || to.isEmpty ? const [] : [to],
      attachmentPaths: [filePath],
      isHTML: false,
    );
    await FlutterEmailSender.send(email);
    return;
  } catch (_) {}

  try {
    final qp = <String, String>{
      if (subject != null && subject.isNotEmpty) 'subject': subject,
      'body': ((body == null || body.isEmpty) ? '' : body) + '\n\nArchivo: ' + filePath,
    };
    final uri = Uri(scheme: 'mailto', path: to ?? '', queryParameters: qp);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {}

  try {
    await Share.shareXFiles([XFile(filePath)], subject: subject, text: body ?? '');
  } catch (_) {}
}
