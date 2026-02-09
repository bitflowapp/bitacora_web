// lib/services/mail_share_web.dart
import 'package:url_launcher/url_launcher.dart';

Future<void> sendMailWithFile({
  required String filePath, // solo nombre informativo
  String? to,
  String? subject,
  String? body,
}) async {
  final uri = Uri(
    scheme: 'mailto',
    path: to ?? '',
    queryParameters: {
      if (subject != null) 'subject': subject,
      'body': _joinBody(body, '\n\nAdjuntar manualmente: $filePath'),
    },
  );
  final ok = await canLaunchUrl(uri);
  if (ok) {
    await launchUrl(uri);
  }
}

String _joinBody(String? a, String b) => (a == null || a.isEmpty) ? b : '$a$b';
