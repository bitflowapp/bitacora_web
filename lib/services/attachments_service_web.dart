// lib/services/attachments_service_web.dart
// Web: adjuntar archivos y tomar foto (cámara) por fila.
// Almacena bytes en Hive. Helpers para exportar, abrir y descargar.

import 'dart:async' as async; // <- para Completer/Future
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;

class AttachmentRecord {
  final String id;
  final String sheetId;
  final int row;
  final String name;
  final String mime;
  final int size;
  final DateTime ts;
  final Uint8List bytes;

  const AttachmentRecord({
    required this.id,
    required this.sheetId,
    required this.row,
    required this.name,
    required this.mime,
    required this.size,
    required this.ts,
    required this.bytes,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'sheetId': sheetId,
    'row': row,
    'name': name,
    'mime': mime,
    'size': size,
    'ts': ts.toIso8601String(),
    'bytes': bytes,
  };

  static AttachmentRecord? from(Object? raw) {
    if (raw is! Map) return null;
    try {
      return AttachmentRecord(
        id: (raw['id'] ?? '') as String,
        sheetId: (raw['sheetId'] ?? '') as String,
        row: (raw['row'] as num?)?.toInt() ?? 0,
        name: (raw['name'] ?? '') as String,
        mime: (raw['mime'] ?? 'application/octet-stream') as String,
        size: (raw['size'] as num?)?.toInt() ?? 0,
        ts: DateTime.tryParse(raw['ts'] as String? ?? '') ?? DateTime.now(),
        bytes: (raw['bytes'] as Uint8List?) ?? Uint8List(0),
      );
    } catch (_) {
      return null;
    }
  }
}

class AttachmentsServiceWeb {
  AttachmentsServiceWeb._();
  static final AttachmentsServiceWeb I = AttachmentsServiceWeb._();

  static const String _boxName = 'att_box_v1';
  Box<dynamic>? _box;

  Future<void> init() async {
    if (!kIsWeb) return;
    if (!Hive.isBoxOpen(_boxName)) {
      try {
        await Hive.initFlutter();
      } catch (_) {}
    }
    _box ??= await _openBoxSafe();
  }

  Future<Box<dynamic>> _openBoxSafe() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
    return Hive.openBox<dynamic>(_boxName);
  }

  bool get ready => _box != null;

  String _genId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final r = math.Random();
    final tail = List.generate(6, (_) => r.nextInt(36))
        .map((n) => 'abcdefghijklmnopqrstuvwxyz0123456789'[n])
        .join();
    return 'att_$now$tail';
  }

  // -------------------- Altas --------------------

  Future<int> pickAndAdd({
    required String sheetId,
    required int row,
    List<XTypeGroup>? typeGroups,
  }) async {
    await init();
    final files = await openFiles(acceptedTypeGroups: typeGroups ?? const []);
    if (files.isEmpty) return 0;
    var count = 0;
    for (final xf in files) {
      final bytes = await xf.readAsBytes();
      final mime = xf.mimeType ?? 'application/octet-stream';
      await add(
        sheetId: sheetId,
        row: row,
        name: xf.name,
        mime: mime,
        bytes: bytes,
      );
      count++;
    }
    return count;
  }

  /// Abre cámara en móviles o selector de imagen en desktop.
  Future<int> captureAndAdd({
    required String sheetId,
    required int row,
  }) async {
    await init();
    if (!kIsWeb) return 0;

    final input = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = false;
    input.setAttribute('capture', 'environment');
    input.click();

    await input.onChange.first;
    final file = (input.files ?? const <html.File>[]).firstOrNull;
    if (file == null) return 0;

    final bytes = await _readAsBytes(file);
    final name = file.name.isNotEmpty ? file.name : _cameraNameFallback();
    final mime = file.type.isNotEmpty ? file.type : 'image/jpeg';

    await add(sheetId: sheetId, row: row, name: name, mime: mime, bytes: bytes);
    return 1;
  }

  Future<String> add({
    required String sheetId,
    required int row,
    required String name,
    required String mime,
    required Uint8List bytes,
  }) async {
    await init();
    final id = _genId();
    final rec = AttachmentRecord(
      id: id,
      sheetId: sheetId,
      row: row,
      name: name,
      mime: mime,
      size: bytes.lengthInBytes,
      ts: DateTime.now().toUtc(),
      bytes: bytes,
    );
    await _box!.put(id, rec.toMap());
    return id;
  }

  // -------------------- Lecturas --------------------

  Future<List<AttachmentRecord>> listFor({
    required String sheetId,
    required int row,
  }) async {
    await init();
    final out = <AttachmentRecord>[];
    for (final v in _box!.values) {
      final rec = AttachmentRecord.from(v);
      if (rec == null) continue;
      if (rec.sheetId == sheetId && rec.row == row) out.add(rec);
    }
    out.sort((a, b) => b.ts.compareTo(a.ts));
    return out;
  }

  Future<Map<int, List<AttachmentRecord>>> listAllRows({
    required String sheetId,
  }) async {
    await init();
    final out = <int, List<AttachmentRecord>>{};
    for (final v in _box!.values) {
      final rec = AttachmentRecord.from(v);
      if (rec == null || rec.sheetId != sheetId) continue;
      (out[rec.row] ??= <AttachmentRecord>[]).add(rec);
    }
    for (final r in out.keys) {
      out[r]!.sort((a, b) => b.ts.compareTo(a.ts));
    }
    return out;
  }

  Future<List<Uint8List>> getPhotoBytesForRow({
    required String sheetId,
    required int row,
  }) async {
    final list = await listFor(sheetId: sheetId, row: row);
    return [
      for (final rec in list)
        if (rec.mime.startsWith('image/')) rec.bytes,
    ];
  }

  // -------------------- Acciones --------------------

  Future<void> delete(String id) async {
    await init();
    await _box!.delete(id);
  }

  Future<void> deleteAllInRow({
    required String sheetId,
    required int row,
  }) async {
    await init();
    final ids = <dynamic>[];
    for (final entry in _box!.toMap().entries) {
      final rec = AttachmentRecord.from(entry.value);
      if (rec == null) continue;
      if (rec.sheetId == sheetId && rec.row == row) ids.add(entry.key);
    }
    if (ids.isNotEmpty) await _box!.deleteAll(ids);
  }

  Future<void> download(String id) async {
    await init();
    final raw = _box!.get(id);
    final rec = AttachmentRecord.from(raw);
    if (rec == null) return;

    if (kIsWeb) {
      final blob = html.Blob([rec.bytes], rec.mime);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final a = html.AnchorElement()
        ..href = url
        ..download = rec.name
        ..style.display = 'none';
      html.document.body?.append(a);
      a.click();
      a.remove();
      async.Future<void>.delayed(const Duration(seconds: 1), () {
        html.Url.revokeObjectUrl(url);
      });
    } else {
      final uri = Uri.dataFromBytes(rec.bytes, mimeType: rec.mime);
      await launchUrl(uri);
    }
  }

  Future<void> openInNewTab(String id) async {
    await init();
    final raw = _box!.get(id);
    final rec = AttachmentRecord.from(raw);
    if (rec == null) return;

    if (kIsWeb) {
      final blob = html.Blob([rec.bytes], rec.mime);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(url, '_blank');
      async.Future<void>.delayed(const Duration(seconds: 1), () {
        html.Url.revokeObjectUrl(url);
      });
    } else {
      final uri = Uri.dataFromBytes(rec.bytes, mimeType: rec.mime);
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  // -------------------- Privados --------------------

  Future<Uint8List> _readAsBytes(html.File f) {
    final reader = html.FileReader();
    final c = async.Completer<Uint8List>();
    reader.onLoad.first.then((_) {
      final buf = reader.result as ByteBuffer;
      c.complete(Uint8List.view(buf));
    });
    reader.onError.first.then((_) => c.complete(Uint8List(0)));
    reader.readAsArrayBuffer(f);
    return c.future;
  }

  String _cameraNameFallback() {
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .replaceAll('-', '');
    return 'foto_$ts.jpg';
  }
}

// Extensión mínima para firstOrNull sin depender de collection.
extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
