// lib/services/remote_mailer.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Error específico del mailer remoto.
class RemoteMailerException implements Exception {
  final String message;
  final String? details;

  const RemoteMailerException({
    required this.message,
    this.details,
  });

  @override
  String toString() {
    final det =
        (details != null && details!.isNotEmpty) ? ' Detalles: $details' : '';
    return 'RemoteMailerException: $message$det';
  }
}

/// Cliente “mailer” que encola el envío en Firestore.
/// Un Cloud Function / backend escucha esta colección y manda el mail real.
class RemoteMailer {
  const RemoteMailer._();

  /// Colección donde se encolan los mails.
  ///
  /// Podés cambiarla con:
  ///   --dart-define=MAIL_REPORTS_COLLECTION=otra_carpeta
  static const String _collectionName = String.fromEnvironment(
    'MAIL_REPORTS_COLLECTION',
    defaultValue: 'mail_reports',
  );

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Asegura que Firebase esté inicializado.
  /// (main() ya lo debería hacer, esto es última red de seguridad).
  static Future<void> _ensureFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  /// Encola un informe con XLSX en Firestore.
  ///
  /// Un backend debe escuchar esta colección y procesar:
  /// - to / subject / message
  /// - xlsxBase64 / fileName
  /// - headers / rows (para logging o re-generar el XLSX si quisieras)
  static Future<void> sendReport({
    required String to,
    required String subject,
    required String message,
    required List<String> headers,
    required List<List<String>> rows,
    required Uint8List xlsxBytes,
    required String fileName,
  }) async {
    await _ensureFirebase();

    final col = _db.collection(_collectionName);

    final payload = <String, dynamic>{
      'to': to,
      'subject': subject,
      'message': message,
      'headers': headers,
      'rows': rows,
      'xlsxBase64': base64Encode(xlsxBytes),
      'fileName': fileName,
      'status': 'queued',
      'createdAt': FieldValue.serverTimestamp(),
      'client': {
        'app': 'Gridnote',
        'platform': kIsWeb ? 'web' : 'flutter',
      },
    };

    try {
      await col.add(payload);
      if (kDebugMode) {
        debugPrint(
          'RemoteMailer Firestore: encolado OK en $_collectionName',
        );
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('RemoteMailer Firestore error: $e\n$st');
      }
      throw RemoteMailerException(
        message: 'No se pudo encolar el correo en Firestore',
        details: e.toString(),
      );
    }
  }
}
