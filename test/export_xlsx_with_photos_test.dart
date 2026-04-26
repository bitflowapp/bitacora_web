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

  String unescapeXml(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  List<String> readSharedStrings(Archive archive) {
    final shared = archive.files
        .where((f) => f.name.replaceAll('\\', '/') == 'xl/sharedStrings.xml')
        .toList(growable: false);
    if (shared.isEmpty) return const <String>[];

    final xml = utf8.decode(shared.first.content as List<int>);
    final out = <String>[];
    final reg = RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true);
    for (final m in reg.allMatches(xml)) {
      final raw = m.group(1) ?? '';
      out.add(unescapeXml(raw));
    }
    return out;
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

  test('video attachments are exported as clickable file hyperlinks', () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Actividad'],
      rows: const [
        ['Inspeccion de bomba'],
      ],
      attachments: const [
        AttachmentRow(
          cellRef: 'A1',
          type: 'video',
          fileName: 'A1_video.mp4',
          notes: 'video de evidencia',
          relativePath: 'attachments/video/A1_video.mp4',
        ),
      ],
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files
        .map((f) => f.name.replaceAll('\\', '/'))
        .toList(growable: false);
    final relXml = archive.files
        .where((f) => f.name.replaceAll('\\', '/').endsWith('.rels'))
        .map((f) => utf8.decode(f.content as List<int>))
        .join('\n');

    expect(names.any((n) => n.startsWith('xl/worksheets/_rels/')), isTrue);
    expect(relXml, contains('attachments/video/A1_video.mp4'));
    expect(readSharedStrings(archive), contains('Abrir video'));
  });

  test('professional evidence sheet hides technical paths and labels',
      () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Activo', 'Estado'],
      rows: const [
        ['Bomba P-101', 'OK'],
      ],
      gpsByRow: [
        GpsExport(
          lat: -34.603722,
          lng: -58.381592,
          accuracy: 8,
          ts: DateTime.parse('2026-04-26T10:15:00Z'),
        ),
      ],
      attachments: [
        AttachmentRow(
          cellRef: 'A1',
          type: 'gps',
          fileName: '',
          notes: 'Coordenadas -34.603722, -58.381592 - Precision 8 m',
          relativePath: '',
          cellValue: 'Bomba P-101',
          linkTarget:
              'https://www.google.com/maps/search/?api=1&query=-34.603722,-58.381592',
          lat: -34.603722,
          lng: -58.381592,
          accuracy: 8,
          addedAt: DateTime.parse('2026-04-26T10:15:00Z'),
        ),
        AttachmentRow(
          cellRef: 'B1',
          type: 'video',
          fileName: 'B1_video_1.mp4',
          notes: 'Video adjunto',
          relativePath: 'attachments/video/B1_video_1.mp4',
          cellValue: 'OK',
        ),
      ],
      includeSummarySheet: true,
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files
        .map((f) => f.name.replaceAll('\\', '/'))
        .toList(growable: false);
    final workbookXml = utf8.decode(
      archive.files
          .firstWhere((f) => f.name.replaceAll('\\', '/') == 'xl/workbook.xml')
          .content as List<int>,
    );
    final sharedStrings = readSharedStrings(archive);
    final visibleText = sharedStrings.join('\n');

    expect(workbookXml, contains('Evidencias'));
    expect(workbookXml, contains('Resumen'));
    expect(visibleText, contains('Ubicacion GPS'));
    expect(visibleText, contains('Video adjunto'));
    expect(visibleText, contains('Abrir video'));
    expect(visibleText, contains('Bomba P-101'));
    expect(visibleText, contains('Evidencias'));
    expect(visibleText, isNot(contains('Attachments')));
    expect(visibleText, isNot(contains('Ruta')));
    expect(visibleText, isNot(contains('storedRef')));
    expect(visibleText, isNot(contains('attachmentId')));
    expect(visibleText, isNot(contains('source=')));
    expect(visibleText, isNot(contains('current')));

    final worksheetXml = names
        .where((n) => n.startsWith('xl/worksheets/') && !n.contains('_rels/'))
        .map((name) {
      final file =
          archive.files.firstWhere((f) => f.name.replaceAll('\\', '/') == name);
      return utf8.decode(file.content as List<int>);
    }).join('\n');
    expect(worksheetXml, isNot(contains('attachments/video/B1_video_1.mp4')));
  });

  test('date-like values are stored with an Excel date format', () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Fecha'],
      rows: const [
        ['2026-04-21T14:35:00'],
        ['21/04/2026 14:35'],
      ],
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final styles = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/') == 'xl/styles.xml',
    );
    final stylesXml = utf8.decode(styles.content as List<int>).toLowerCase();

    expect(stylesXml, contains('dd/mm/yyyy hh:mm'));
  });

  test('invalid calendar dates stay as text instead of rolling over', () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Fecha'],
      rows: const [
        ['31/02/2026 14:35'],
      ],
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    expect(readSharedStrings(archive), contains('31/02/2026 14:35'));
  });

  test('very large square images are bounded before embedding', () async {
    final huge = img.Image(width: 3000, height: 3000);
    img.fill(huge, color: img.ColorRgb8(12, 120, 220));
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Foto'],
      rows: const [
        [''],
      ],
      embeddedPhotos: [
        EmbeddedPhoto(
          rowIndex: 0,
          colIndex: 0,
          bytes: Uint8List.fromList(img.encodeJpg(huge, quality: 90)),
        ),
      ],
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final media = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/').startsWith('xl/media/'),
    );
    final decoded = img.decodeImage(Uint8List.fromList(
      (media.content as List<int>).toList(growable: false),
    ));

    expect(decoded, isNotNull);
    expect(decoded!.width <= 1280, isTrue);
    expect(decoded.height <= 960, isTrue);
  });
}
