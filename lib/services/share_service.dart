import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class ShareService {
  static bool get _isMobile =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

  /// savedPathOrName:
  /// - Web: abre el cliente de correo (mailto) sin adjunto (los navegadores no adjuntan).
  /// - Android/iOS: intenta adjuntar con flutter_email_sender, fallback a compartir o mailto.
  /// - Windows/macOS/Linux: comparte el archivo con share_plus; fallback mailto con la ruta en el cuerpo.
  static Future<void> sendExcel(String savedPathOrName) async {
    // WEB → mailto sin adjunto
    if (kIsWeb) {
      final uri = Uri(
        scheme: 'mailto',
        queryParameters: const {
          'subject': 'Bitácora - Exportación XLSX',
          'body': 'Se descargó el archivo desde el navegador.',
        },
      );
      await launchUrl(uri);
      return;
    }

    // ANDROID/iOS → adjunto real
    if (_isMobile) {
      try {
        final email = Email(
          body: 'Adjunto XLSX.',
          subject: 'Bitácora - Exportación',
          recipients: const [],
          attachmentPaths: [savedPathOrName],
          isHTML: false,
        );
        await FlutterEmailSender.send(email);
        return;
      } catch (_) {
        // sigue al fallback
      }
    }

    // DESKTOP (o fallback mobile) → compartir archivo, y si falla, mailto con ruta
    try {
      await Share.shareXFiles([XFile(savedPathOrName)],
          text: 'Bitácora - Exportación');
    } catch (_) {
      final uri = Uri(
        scheme: 'mailto',
        queryParameters: {
          'subject': 'Bitácora - Exportación',
          'body':
          'No se pudo adjuntar automáticamente.\nRuta del archivo: $savedPathOrName',
        },
      );
      await launchUrl(uri);
    }
  }
}
