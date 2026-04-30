import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bitacora_web/services/export_xlsx_with_photos.dart';
import 'package:bitacora_web/services/photo_bytes_resolver.dart';
import 'package:bitacora_web/services/photo_json_codec.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Uint8List makeTinyPng() {
    final tiny = img.Image(width: 1, height: 1);
    tiny.setPixelRgba(0, 0, 255, 0, 0, 255);
    return Uint8List.fromList(img.encodePng(tiny));
  }

  void expectNoLocalPathTokens(String xml) {
    expect(xml.contains('file:'), isFalse);
    expect(xml.contains('content://'), isFalse);
    expect(xml.contains('/storage/'), isFalse);
    expect(xml.contains('c:\\'), isFalse);
    expect(xml.contains('dcim'), isFalse);
  }

  Map<String, String> parseDrawingRels(String relXml) {
    final out = <String, String>{};
    final relReg = RegExp(
      r'<Relationship[^>]*Id="([^"]+)"[^>]*Target="([^"]+)"',
      caseSensitive: false,
    );
    for (final m in relReg.allMatches(relXml)) {
      final id = m.group(1) ?? '';
      final target = m.group(2) ?? '';
      if (id.isEmpty || target.isEmpty) continue;
      out[id] = target;
    }
    return out;
  }

  String normalizeTarget(String target) {
    final cleaned = target.replaceAll('\\', '/');
    if (cleaned.startsWith('../')) {
      return 'xl/${cleaned.substring(3)}';
    }
    if (cleaned.startsWith('/')) {
      return cleaned.substring(1);
    }
    return cleaned.startsWith('xl/') ? cleaned : 'xl/$cleaned';
  }

  void expectDrawingsReferenceMedia(Archive archive, List<String> names) {
    final drawingXmls = names.where(
      (n) => n.startsWith('xl/drawings/drawing') && !n.contains('_rels/'),
    );

    for (final name in drawingXmls) {
      final file =
          archive.files.firstWhere((f) => f.name.replaceAll('\\', '/') == name);
      final xml = utf8.decode(file.content as List<int>);
      final embedIds = RegExp(r'r:embed="([^"]+)"')
          .allMatches(xml)
          .map((m) => m.group(1) ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      final relName = 'xl/drawings/_rels/${name.split('/').last}.rels';
      final relFile = archive.files.firstWhere(
        (f) => f.name.replaceAll('\\', '/') == relName,
      );
      final relXml = utf8.decode(relFile.content as List<int>);
      final rels = parseDrawingRels(relXml);

      for (final id in embedIds) {
        final target = rels[id];
        expect(target, isNotNull);
        final normalized = normalizeTarget(target!);
        expect(names.contains(normalized), isTrue);
      }
    }
  }

  void expectMediaAndDrawings(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files
        .map((f) => f.name.replaceAll('\\', '/'))
        .toList(growable: false);

    final hasMedia = names.any((n) => n.startsWith('xl/media/'));
    expect(hasMedia, isTrue);

    final drawingFiles =
        names.where((n) => n.startsWith('xl/drawings/drawing'));
    expect(drawingFiles.isNotEmpty, isTrue);

    final drawingRelFiles =
        names.where((n) => n.startsWith('xl/drawings/_rels/'));
    expect(drawingRelFiles.isNotEmpty, isTrue);

    expectDrawingsReferenceMedia(archive, names);

    final hasSharedStrings = names.contains('xl/sharedStrings.xml');
    if (hasSharedStrings) {
      final shared = archive.files.firstWhere(
        (f) => f.name.replaceAll('\\', '/') == 'xl/sharedStrings.xml',
      );
      final sharedXml = utf8.decode(shared.content as List<int>).toLowerCase();
      expectNoLocalPathTokens(sharedXml);
    }

    final worksheetXmls = names.where(
      (n) => n.startsWith('xl/worksheets/') && !n.contains('_rels/'),
    );
    for (final name in worksheetXmls) {
      final file =
          archive.files.firstWhere((f) => f.name.replaceAll('\\', '/') == name);
      final xml = utf8.decode(file.content as List<int>).toLowerCase();
      expectNoLocalPathTokens(xml);
    }

    final drawingXmls = names.where(
      (n) => n.startsWith('xl/drawings/drawing') && !n.contains('_rels/'),
    );
    for (final name in drawingXmls) {
      final file =
          archive.files.firstWhere((f) => f.name.replaceAll('\\', '/') == name);
      final xml = utf8.decode(file.content as List<int>).toLowerCase();
      expectNoLocalPathTokens(xml);
    }
  }

  String readArchiveText(Archive archive, String name) {
    final normalized = name.replaceAll('\\', '/');
    final file = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/') == normalized,
      orElse: () => throw StateError('Missing XLSX entry: $normalized'),
    );
    return utf8.decode(file.content as List<int>);
  }

  List<String> sharedStringValues(Archive archive) {
    final names = archive.files
        .map((f) => f.name.replaceAll('\\', '/'))
        .toList(growable: false);
    if (!names.contains('xl/sharedStrings.xml')) return const <String>[];
    final xml = readArchiveText(archive, 'xl/sharedStrings.xml');
    return RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
        .allMatches(xml)
        .map((m) => m.group(1) ?? '')
        .toList(growable: false);
  }

  String? styleIdForCell(String sheetXml, String cellRef) {
    final match = RegExp(
      '<c r="$cellRef"[^>]*\\bs="([^"]+)"',
    ).firstMatch(sheetXml);
    return match?.group(1);
  }

  test('buildXlsxWithPhotos includes media + drawings and no names', () async {
    final png = makeTinyPng();
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Dato'],
      rows: const [
        ['fila 1'],
        ['fila 2'],
        ['fila 3'],
      ],
      embeddedPhotos: [
        EmbeddedPhoto(rowIndex: 0, colIndex: 0, bytes: png),
        EmbeddedPhoto(rowIndex: 2, colIndex: 0, bytes: png),
      ],
      attachments: const [
        AttachmentRow(
          cellRef: 'A1',
          type: 'photo',
          fileName: 'A1_p1_foto.jpg',
          notes: '',
          relativePath: 'attachments/photos/A1_p1_foto.jpg',
        ),
      ],
    );

    expect(bytes, isNotEmpty);
    expectMediaAndDrawings(bytes);
  });

  test('re-open with dataB64 preserves bytes and embeds photos', () async {
    final png = makeTinyPng();
    final dataB64 = base64Encode(png);

    final encoded = PhotoJson(
      name: 'camera_1.jpg',
      mime: 'image/jpeg',
      thumbB64: '',
      addedAt: DateTime.parse('2026-01-01T12:00:00.000Z'),
      path: '',
      dataB64: dataB64,
      lat: null,
      lng: null,
      accuracyM: null,
      isLastKnown: false,
    ).toJson(persistThumb: true);

    final decoded = PhotoJson.fromJson(encoded);
    final resolved = await PhotoBytesResolver.resolve(
      path: decoded.path,
      dataB64: decoded.dataB64,
      thumbB64: decoded.thumbB64,
      readFromPath: (_) async => null,
      debugTag: 'test_reopen',
    );

    final resolvedBytes = resolved ?? Uint8List(0);
    expect(resolvedBytes.isNotEmpty, isTrue);

    final bytes = await buildXlsxWithPhotos(
      columns: const ['Dato'],
      rows: const [
        ['fila 1'],
      ],
      embeddedPhotos: [
        EmbeddedPhoto(rowIndex: 0, colIndex: 0, bytes: resolvedBytes),
      ],
    );

    expectMediaAndDrawings(bytes);
  });

  test('buildXlsxWithPhotos applies visible business formatting', () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const [
        'Fecha',
        'Estado',
        'Foto / Evidencia',
        'Observaciones',
        'Descripcion',
        'Col 12',
        'Col 13',
        'Col 14',
      ],
      rows: const [
        [
          '22/04/2026 00:00',
          'OK',
          'Sin evidencia',
          'Observacion suficientemente larga para validar ajuste de ancho.',
          'Texto comun',
          '',
          '',
          '',
        ],
        [
          '23/04/2026 00:00:00',
          'Observado',
          'sin evidencias',
          'Otra observacion de campo.',
          'Texto comun',
          '',
          '',
          '',
        ],
        [
          '2026-04-24T00:00:00.000',
          'Crítico',
          '',
          'Requiere seguimiento.',
          'Texto comun',
          '',
          '',
          '',
        ],
      ],
      includeIndexColumn: false,
      includeSummarySheet: true,
      sheetName: 'Demo - Proteccion catodica Loma',
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final sharedValues = sharedStringValues(archive);
    final sharedXml = readArchiveText(archive, 'xl/sharedStrings.xml');
    final sheetXml = readArchiveText(archive, 'xl/worksheets/sheet1.xml');
    final summaryXml = readArchiveText(archive, 'xl/worksheets/sheet2.xml');
    final stylesXml = readArchiveText(archive, 'xl/styles.xml');

    expect(sharedValues, isNot(contains('Sin evidencia')));
    expect(sharedValues, contains('\u2014'));
    expect(sharedValues, contains('Sin evidencia adjunta en esta exportación'));
    expect(sharedXml.contains('Col 12'), isFalse);
    expect(sharedXml.contains('Col 13'), isFalse);
    expect(sharedXml.contains('Col 14'), isFalse);

    expect(sheetXml.contains('<autoFilter'), isTrue);
    expect(sheetXml.contains('ref="A1:E4"'), isTrue);
    expect(summaryXml.contains('r="B8"'), isTrue);

    expect(stylesXml.contains('formatCode="dd/mm/yyyy"'), isTrue);
    expect(stylesXml.contains('formatCode="dd/mm/yyyy hh:mm"'), isFalse);

    final okStyle = styleIdForCell(sheetXml, 'B2');
    final observedStyle = styleIdForCell(sheetXml, 'B3');
    final criticalStyle = styleIdForCell(sheetXml, 'B4');
    final normalStyle = styleIdForCell(sheetXml, 'E3');
    expect(okStyle, isNotNull);
    expect(observedStyle, isNotNull);
    expect(criticalStyle, isNotNull);
    expect(okStyle, isNot(normalStyle));
    expect(observedStyle, isNot(normalStyle));
    expect(criticalStyle, isNot(normalStyle));
    expect({okStyle, observedStyle, criticalStyle}.length, 3);
  });

  test('generate sample XLSX with photos for manual review', () async {
    final png = makeTinyPng();
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Dato'],
      rows: const [
        ['fila 1'],
        ['fila 2'],
        ['fila 3'],
      ],
      embeddedPhotos: [
        EmbeddedPhoto(rowIndex: 0, colIndex: 0, bytes: png),
        EmbeddedPhoto(rowIndex: 1, colIndex: 0, bytes: png),
        EmbeddedPhoto(rowIndex: 2, colIndex: 0, bytes: png),
      ],
      attachments: const [
        AttachmentRow(
          cellRef: 'A1',
          type: 'photo',
          fileName: 'A1_p1_foto.jpg',
          notes: '',
          relativePath: 'attachments/photos/A1_p1_foto.jpg',
        ),
      ],
      includeIndexColumn: false,
      includeCoverSheet: true,
      includeSummarySheet: true,
    );

    final dir = Directory('build/exports');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File('build/exports/sample_with_photos.xlsx');
    file.writeAsBytesSync(bytes, flush: true);

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync() > 0, isTrue);
  });
}
