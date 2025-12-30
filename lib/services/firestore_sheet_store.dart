// lib/services/firestore_sheet_store.dart
//
// Backup y restauración de planillas del editor en Firestore.
// Usa el proyecto "bitacora-28be4" configurado con flutterfire.
//
// Supone que tu editor puede exportar/importar el estado de la planilla
// como Map<String, dynamic> (JSON), por ejemplo: tableState.toJson().

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreSheetStore {
  FirestoreSheetStore._();

  static final FirestoreSheetStore instance = FirestoreSheetStore._();

  static const String _collectionName = 'bitacora_sheets';

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(_collectionName);

  /// Guarda una planilla en Firestore.
  ///
  /// [sheetId]: ID estable de la planilla (por ejemplo, un UUID o el ID que ya usa Bitácora).
  /// [data]: JSON completo de la planilla (columnas, filas, metadatos).
  /// [name]: nombre amigable de la planilla (opcional).
  /// [deviceInfo]: texto corto del dispositivo/origen (opcional).
  Future<void> saveSheet({
    required String sheetId,
    required Map<String, dynamic> data,
    String? name,
    String? deviceInfo,
  }) async {
    final now = DateTime.now();

    await _collection.doc(sheetId).set(
      <String, dynamic>{
        'name': name,
        'data': data,
        'device': deviceInfo,
        'updatedAt': now.toUtc(),
      },
      SetOptions(merge: true),
    );
  }

  /// Carga el JSON de una planilla desde Firestore.
  ///
  /// Devuelve null si la planilla no existe o está vacía.
  Future<Map<String, dynamic>?> loadSheet(String sheetId) async {
    final doc = await _collection.doc(sheetId).get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data();
    if (data == null) {
      return null;
    }

    final dynamic raw = data['data'];
    if (raw is Map<String, dynamic>) {
      return Map<String, dynamic>.from(raw);
    }

    return null;
  }

  /// Elimina una planilla de Firestore.
  Future<void> deleteSheet(String sheetId) async {
    await _collection.doc(sheetId).delete();
  }

  /// Devuelve una lista reactiva de planillas disponibles,
  /// ordenadas por fecha de actualización descendente.
  Stream<List<SheetSummary>> watchSheets() {
    return _collection
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
      return snapshot.docs.map(SheetSummary.fromDoc).toList();
    });
  }
}

class SheetSummary {
  final String id;
  final String? name;
  final String? device;
  final DateTime? updatedAt;

  const SheetSummary({
    required this.id,
    required this.name,
    required this.device,
    required this.updatedAt,
  });

  factory SheetSummary.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();
    final dynamic rawDate = data['updatedAt'];

    DateTime? updatedAt;

    if (rawDate is Timestamp) {
      updatedAt = rawDate.toDate();
    } else if (rawDate is DateTime) {
      updatedAt = rawDate;
    } else if (rawDate is String) {
      // Fallback por si alguna versión vieja guardó ISO8601.
      updatedAt = DateTime.tryParse(rawDate);
    }

    return SheetSummary(
      id: doc.id,
      name: data['name'] as String?,
      device: data['device'] as String?,
      updatedAt: updatedAt,
    );
  }
}
