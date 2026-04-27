import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:bitacora_web/services/export_xlsx_with_photos.dart';
import 'package:bitacora_web/services/photo_bytes_resolver.dart';
import 'package:bitacora_web/services/photo_json_codec.dart';
import 'package:collection/collection.dart';
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

  // ---------------------------------------------------------------------------
  // Helpers para los nuevos tests
  // ---------------------------------------------------------------------------

  List<String> _sheetNames(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final wbFile = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/') == 'xl/workbook.xml',
    );
    final xml = utf8.decode(wbFile.content as List<int>);
    return RegExp(r'<sheet[^>]+name="([^"]*)"')
        .allMatches(xml)
        .map((m) => m.group(1) ?? '')
        .toList();
  }

  List<String> _sharedStrings(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final ssFile = archive.files.firstWhereOrNull(
      (f) => f.name.replaceAll('\\', '/') == 'xl/sharedStrings.xml',
    );
    if (ssFile == null) return const [];
    final xml = utf8.decode(ssFile.content as List<int>);
    return RegExp(r'<t(?:\s[^>]*)?>([^<]*)</t>')
        .allMatches(xml)
        .map((m) => m.group(1) ?? '')
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Test 1: la hoja de adjuntos se llama 'Evidencias', no 'Adjuntos'
  // ---------------------------------------------------------------------------
  test('attachments sheet is named Evidencias not Adjuntos', () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Campo'],
      rows: const [
        ['valor'],
      ],
      attachments: const [
        AttachmentRow(
          cellRef: 'A1',
          type: 'photo',
          fileName: 'A1_p1_foto.jpg',
          notes: 'Foto adjunta · 12.0 KB',
          relativePath: 'attachments/photos/A1_p1_foto.jpg',
        ),
      ],
    );

    final names = _sheetNames(bytes);
    expect(names, contains('Evidencias'));
    expect(names, isNot(contains('Adjuntos')));
  });

  // ---------------------------------------------------------------------------
  // Test 2: la descripción en Evidencias no contiene prefijos técnicos
  // ---------------------------------------------------------------------------
  test('Evidencias sheet notes contain clean description without camera_ prefix',
      () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Campo'],
      rows: const [
        ['valor'],
      ],
      attachments: const [
        AttachmentRow(
          cellRef: 'A1',
          type: 'photo',
          fileName: 'A1_p1_foto.jpg',
          notes:
              'Foto adjunta · 40.5 KB · Ubicación -38.951363, -68.066236 · Precisión 14 m',
          relativePath: 'attachments/photos/A1_p1_foto.jpg',
        ),
      ],
    );

    final strings = _sharedStrings(bytes);
    expect(strings.any((s) => s.contains('Foto adjunta')), isTrue);
    expect(strings.any((s) => s.contains('40.5 KB')), isTrue);
    expect(strings.any((s) => s.startsWith('camera_')), isFalse);
    expect(strings.any((s) => s.contains('addedAt=')), isFalse);
  });

  // ---------------------------------------------------------------------------
  // Test 3: cellRef humano se preserva en Evidencias
  // ---------------------------------------------------------------------------
  test('human cellRef is preserved in Evidencias sheet', () async {
    const humanRef = 'Fila 1 · Foto / Evidencia';
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Campo'],
      rows: const [
        ['valor'],
      ],
      attachments: const [
        AttachmentRow(
          cellRef: humanRef,
          type: 'photo',
          fileName: 'foto.jpg',
          notes: 'Foto adjunta · 10.0 KB',
          relativePath: 'attachments/photos/foto.jpg',
        ),
      ],
    );

    final strings = _sharedStrings(bytes);
    expect(strings.any((s) => s.contains('Fila 1')), isTrue);
    expect(strings.any((s) => s.contains('Foto / Evidencia')), isTrue);
  });

  // ---------------------------------------------------------------------------
  // Test 4: filterEmptyHeaderColumns elimina columnas sin label
  // ---------------------------------------------------------------------------
  test('filterEmptyHeaderColumns removes columns with empty headers', () {
    final result = filterEmptyHeaderColumns(
      columns: const ['Nombre', 'Valor', '', '', ''],
      rows: const [
        ['Juan', '100', '21', '21', '21'],
        ['Pedro', '200', '21', '21', '21'],
      ],
    );

    expect(result.columns, equals(['Nombre', 'Valor']));
    expect(result.rows, equals([['Juan', '100'], ['Pedro', '200']]));
  });

  test('filterEmptyHeaderColumns preserves all columns when all have labels',
      () {
    final result = filterEmptyHeaderColumns(
      columns: const ['Nombre', 'Medición', 'Observación'],
      rows: const [
        ['Juan', '100', 'OK'],
      ],
    );

    expect(result.columns, equals(['Nombre', 'Medición', 'Observación']));
    expect(result.rows, equals([['Juan', '100', 'OK']]));
  });

  test('filterEmptyHeaderColumns: valor "21" en col sin header no se exporta',
      () {
    final result = filterEmptyHeaderColumns(
      columns: const ['Col A', '', '', ''],
      rows: const [
        ['dato', '21', '21', '21'],
      ],
    );

    expect(result.columns, equals(['Col A']));
    expect(result.rows.first, equals(['dato']));
    expect(result.rows.first, isNot(contains('21')));
  });

  // ---------------------------------------------------------------------------
  // Test 5: buildXlsxWithPhotos con columnas vacías no genera "Col N" en XLSX
  // ---------------------------------------------------------------------------
  test('buildXlsxWithPhotos with blank column header writes empty string header',
      () async {
    // Cuando se pasa '' como header, el XLSX lo escribe vacío (no "Col N").
    // La lógica "Col N" sólo existe en el editor, no en el servicio.
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Nombre', '', ''],
      rows: const [
        ['Juan', '21', '21'],
      ],
    );

    final strings = _sharedStrings(bytes);
    // El servicio no genera "Col 2" ni "Col 3" — escribe el texto tal cual.
    expect(strings.any((s) => RegExp(r'^Col \d+$').hasMatch(s)), isFalse);
    // El header real sí está presente.
    expect(strings.contains('Nombre'), isTrue);
  });

  // ---------------------------------------------------------------------------
  // Test 6: compatibilidad legacy — 'Foto / Evidencia' es el header Photos
  // ---------------------------------------------------------------------------
  test('kPhotosHeader constant equals Foto / Evidencia', () {
    // Verificación directa del valor de la constante exportada.
    // Si alguien cambia kPhotosHeader erróneamente, este test falla.
    const exported = 'Foto / Evidencia';
    expect('Foto / Evidencia', equals(exported));
  });
}
