// lib/services/mail_report_service.dart
//
// Envía correos vía microservicio Node+Resend (CloudMailer)
// usando el endpoint /send-xlsx.

import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'cloud_mailer.dart';

@immutable
class MailReportException implements Exception {
  final String message;
  final Object? cause;

  const MailReportException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause == null) return 'MailReportException: $message';
    return 'MailReportException: $message (cause: $cause)';
  }
}

class MailReportService {
  MailReportService._({CloudMailer? mailer})
      : _mailer = mailer ?? CloudMailer.I;

  final CloudMailer _mailer;

  // Singleton global para usar como MailReportService.I
  static final MailReportService I = MailReportService._();

  /// Envía el XLSX vía microservicio Node+Resend.
  ///
  /// Lanza [MailReportException] si algo falla.
  Future<void> sendReport({
    required String to,
    String? subject,
    String? message,
    required String fileName,
    required List<int> xlsxBytes,
    String? sheetId,   // se mantiene por compatibilidad
    String? deviceInfo, // idem
  }) async {
    final trimmedTo = to.trim();
    if (trimmedTo.isEmpty || !trimmedTo.contains('@')) {
      throw const MailReportException('Correo destino inválido');
    }

    if (xlsxBytes.isEmpty) {
      throw const MailReportException(
        'xlsxBytes está vacío; revisá el exportador XLSX.',
      );
    }

    final safeSubject = (subject == null || subject.trim().isEmpty)
        ? 'Reporte Gridnote'
        : subject.trim();

    final safeMessage = (message == null || message.isEmpty)
        ? 'Adjunto XLSX generado desde Gridnote.'
        : message;

    final safeFileName =
    fileName.trim().isEmpty ? 'Gridnote.xlsx' : fileName.trim();

    // Aseguramos Uint8List para CloudMailer.
    final Uint8List bytes = xlsxBytes is Uint8List
        ? xlsxBytes
        : Uint8List.fromList(xlsxBytes);

    try {
      await _mailer.sendXlsx(
        to: trimmedTo,
        fileName: safeFileName,
        bytes: bytes,
        subject: safeSubject,
        text: safeMessage,
        html: '<p>${_escapeHtml(safeMessage)}</p>',
      );
    } catch (e, st) {
      debugPrint('MailReportService: error enviando correo: $e\n$st');
      throw MailReportException(
        'Error enviando correo vía CloudMailer',
        e,
      );
    }
  }

  String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
