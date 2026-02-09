// lib/services/mail_report_service.dart
//
// Envía correos vía microservicio Node+Resend (CloudMailer)
// usando el endpoint /send-xlsx.
//
// Este enfoque funciona en Android/iOS/Web porque el envío real lo hace el server.
// La app sólo sube bytes del XLSX.

import 'dart:convert' show HtmlEscape, HtmlEscapeMode;
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

  /// Singleton global para usar como MailReportService.I
  static final MailReportService I = MailReportService._();

  /// Límite defensivo. Ajustalo si tu backend acepta más.
  /// Resend suele estar bien con adjuntos moderados; 15MB es un buen default.
  static const int maxXlsxBytes = 15 * 1024 * 1024;

  static final HtmlEscape _html = HtmlEscape(HtmlEscapeMode.element);

  /// Envía el XLSX vía microservicio Node+Resend.
  ///
  /// Lanza [MailReportException] si algo falla.
  Future<void> sendReport({
    required String to,
    String? subject,
    String? message,
    required String fileName,
    required List<int> xlsxBytes,
    String? sheetId, // se mantiene por compatibilidad
    String? deviceInfo, // idem
  }) async {
    final trimmedTo = to.trim();
    if (!_looksLikeEmail(trimmedTo)) {
      throw const MailReportException('Correo destino inválido');
    }

    if (xlsxBytes.isEmpty) {
      throw const MailReportException(
        'xlsxBytes está vacío; revisá el exportador XLSX.',
      );
    }

    // Evita mandar una bomba al backend por error.
    final int byteLen = xlsxBytes.length;
    if (byteLen > maxXlsxBytes) {
      throw MailReportException(
        'El XLSX excede el máximo permitido (${_formatBytes(maxXlsxBytes)}). '
        'Tamaño actual: ${_formatBytes(byteLen)}.',
      );
    }

    final safeSubject = (subject == null || subject.trim().isEmpty)
        ? 'Reporte Gridnote'
        : subject.trim();

    final safeMessage = (message == null || message.trim().isEmpty)
        ? 'Adjunto XLSX generado desde Gridnote.'
        : message.trim();

    final safeFileName = _sanitizeXlsxFileName(fileName);

    // Aseguramos Uint8List sin copiar si ya viene así.
    final Uint8List bytes = xlsxBytes is Uint8List
        ? (xlsxBytes as Uint8List)
        : Uint8List.fromList(xlsxBytes);

    // Metadata opcional para logs del backend (si CloudMailer lo soporta).
    // Si tu CloudMailer.sendXlsx no acepta estos campos, eliminá esta sección.
    final String metaLine =
        _buildMetaLine(sheetId: sheetId, deviceInfo: deviceInfo);

    final String finalText =
        metaLine.isEmpty ? safeMessage : '$safeMessage\n\n$metaLine';
    final String finalHtml = metaLine.isEmpty
        ? '<p>${_html.convert(safeMessage)}</p>'
        : '<p>${_html.convert(safeMessage)}</p><pre>${_html.convert(metaLine)}</pre>';

    try {
      await _mailer.sendXlsx(
        to: trimmedTo,
        fileName: safeFileName,
        bytes: bytes,
        subject: safeSubject,
        text: finalText,
        html: finalHtml,
      );
    } catch (e, st) {
      debugPrint('MailReportService: error enviando correo: $e\n$st');
      throw MailReportException('Error enviando correo vía CloudMailer', e);
    }
  }

  bool _looksLikeEmail(String s) {
    if (s.isEmpty || s.length > 320) return false;
    final at = s.indexOf('@');
    if (at <= 0 || at != s.lastIndexOf('@') || at == s.length - 1) return false;
    // No es RFC-perfecto; es un filtro razonable para UI.
    if (s.contains(' ')) return false;
    return true;
  }

  String _sanitizeXlsxFileName(String name) {
    var n = name.trim();
    if (n.isEmpty) n = 'Gridnote.xlsx';

    // Limpia caracteres conflictivos para adjuntos/nombres.
    n = n.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    n = n.replaceAll('..', '.');

    if (!n.toLowerCase().endsWith('.xlsx')) {
      n = '$n.xlsx';
    }

    // Evita nombres absurdamente largos.
    if (n.length > 180) {
      final base = n.substring(0, 180).trimRight();
      n = base.toLowerCase().endsWith('.xlsx') ? base : '$base.xlsx';
    }

    // Si quedó vacío por algún motivo raro.
    if (n.isEmpty) n = 'Gridnote.xlsx';
    return n;
  }

  String _buildMetaLine({String? sheetId, String? deviceInfo}) {
    final sid = (sheetId ?? '').trim();
    final dev = (deviceInfo ?? '').trim();

    if (sid.isEmpty && dev.isEmpty) return '';

    final parts = <String>[];
    if (sid.isNotEmpty) parts.add('sheetId=$sid');
    if (dev.isNotEmpty) parts.add('device=$dev');
    return parts.join(' | ');
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }
}
