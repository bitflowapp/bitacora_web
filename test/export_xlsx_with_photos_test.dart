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

  String archiveText(Archive archive, String name) {
    final file = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/') == name,
    );
    return utf8.decode(file.content as List<int>);
  }

  List<String> sharedStrings(Archive archive) {
    final names =
        archive.files.map((f) => f.name.replaceAll('\\', '/')).toSet();
    if (!names.contains('xl/sharedStrings.xml')) return const <String>[];
    final sharedXml = archiveText(archive, 'xl/sharedStrings.xml');
    return RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
        .allMatches(sharedXml)
        .map((m) => m.group(1) ?? '')
        .toList(growable: false);
  }

  Map<String, String> sheetXmlByName(Archive archive) {
    final workbookXml = archiveText(archive, 'xl/workbook.xml');
    final relsXml = archiveText(archive, 'xl/_rels/workbook.xml.rels');

    final relById = <String, String>{};
    for (final m in RegExp(
      r'<Relationship[^>]*Id="([^"]+)"[^>]*Target="([^"]+)"',
      caseSensitive: false,
    ).allMatches(relsXml)) {
      final id = m.group(1) ?? '';
      final target = m.group(2) ?? '';
      if (id.isEmpty || target.isEmpty) continue;
      relById[id] = normalizeTarget(target);
    }

    final out = <String, String>{};
    for (final m in RegExp(
      r'<sheet[^>]*name="([^"]+)"[^>]*r:id="([^"]+)"',
      caseSensitive: false,
    ).allMatches(workbookXml)) {
      final name = m.group(1) ?? '';
      final relId = m.group(2) ?? '';
      final target = relById[relId];
      if (name.isEmpty || target == null) continue;
      out[name] = target;
    }
    return out;
  }

  List<String> headerRowValuesForSheet(Archive archive, String sheetName) {
    final map = sheetXmlByName(archive);
    final sheetPath = map[sheetName];
    expect(sheetPath, isNotNull, reason: 'Sheet $sheetName should exist');
    final xml = archiveText(archive, sheetPath!);
    final shared = sharedStrings(archive);

    final rowMatch = RegExp(
      r'<row[^>]*r="1"[^>]*>(.*?)</row>',
      dotAll: true,
      caseSensitive: false,
    ).firstMatch(xml);
    if (rowMatch == null) return const <String>[];
    final rowXml = rowMatch.group(1) ?? '';

    final values = <String>[];
    for (final cell in RegExp(r'<c\b[^>]*>.*?</c>', dotAll: true)
        .allMatches(rowXml)
        .map((m) => m.group(0) ?? '')) {
      final type = RegExp(r'\bt="([^"]+)"', caseSensitive: false)
              .firstMatch(cell)
              ?.group(1) ??
          '';
      if (type == 's') {
        final raw =
            RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(cell)?.group(1) ??
                '';
        final idx = int.tryParse(raw.trim()) ?? -1;
        values.add((idx >= 0 && idx < shared.length) ? shared[idx] : '');
        continue;
      }
      if (type == 'inlineStr') {
        values.add(
          RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true)
                  .firstMatch(cell)
                  ?.group(1) ??
              '',
        );
        continue;
      }
      values.add(
        RegExp(r'<v>(.*?)</v>', dotAll: true).firstMatch(cell)?.group(1) ?? '',
      );
    }
    return values;
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
      attachments: [
        AttachmentRow(
          sheetName: 'Control Diario',
          cellRef: 'A1',
          rowLabel: 'Fila-1',
          type: 'foto',
          fileName: 'foto_Control_Diario_A1_2026-03-10_03-01.jpg',
          description: '',
          addedAt: DateTime(2026, 3, 10, 3, 1),
          relativePath:
              'evidencias/fotos/foto_Control_Diario_A1_2026-03-10_03-01.jpg',
        ),
      ],
    );

    expect(bytes, isNotEmpty);
    expectMediaAndDrawings(bytes);
  });

  test('xlsx includes professional workbook sheets and evidence columns',
      () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Actividad', 'Fecha'],
      rows: const [
        ['Inspeccion', '2026-03-10T03:01:00Z'],
      ],
      attachments: [
        AttachmentRow(
          sheetName: 'Control Diario',
          cellRef: 'B2',
          rowLabel: 'Fila-2',
          type: 'foto',
          fileName: 'foto_Control_Diario_B2_2026-03-10_03-01.jpg',
          description: 'Equipo principal',
          addedAt: DateTime(2026, 3, 10, 3, 1),
          relativePath:
              'evidencias/fotos/foto_Control_Diario_B2_2026-03-10_03-01.jpg',
          rowNumber: 2,
          latitude: -34.603722,
          longitude: -58.381592,
        ),
      ],
      includeIndexColumn: false,
      includeCoverSheet: true,
      includeSummarySheet: true,
      exportFileName: 'BitFlow_Control_Diario_2026-03-10_03-01.xlsx',
      clientName: 'Acme',
      projectName: 'Obra Norte',
      responsibleName: 'Inspector Uno',
      observations: 'Turno mañana',
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final sheets = sheetXmlByName(archive);
    expect(sheets.keys.take(2).toList(), equals(['Caratula', 'Resumen']));

    final planillaPath = sheets['PLANILLA'];
    expect(planillaPath, isNotNull);
    final planillaXml = archiveText(archive, planillaPath!);
    expect(planillaXml.contains('<autoFilter '), isTrue);
    expect(planillaXml.contains('<pane '), isTrue);

    final headers = headerRowValuesForSheet(archive, 'Evidencias');
    expect(
      headers,
      equals([
        'Hoja',
        'Celda',
        'Fila',
        'Tipo',
        'Archivo',
        'Descripción',
        'Fecha',
        'Latitud',
        'Longitud',
        'Ruta relativa',
      ]),
    );

    final shared = sharedStrings(archive);
    expect(shared.contains('BitFlow | Exportación profesional'), isTrue);
    expect(shared.contains('BitFlow | Resumen de exportación'), isTrue);
    expect(shared.contains('Total de videos'), isTrue);

    final stylesXml = archiveText(archive, 'xl/styles.xml');
    expect(stylesXml.contains('yyyy-mm-dd hh:mm'), isTrue);
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
      attachments: [
        AttachmentRow(
          sheetName: 'Control Diario',
          cellRef: 'A1',
          rowLabel: 'Fila-1',
          type: 'foto',
          fileName: 'foto_Control_Diario_A1_2026-03-10_03-01.jpg',
          description: '',
          addedAt: DateTime(2026, 3, 10, 3, 1),
          relativePath:
              'evidencias/fotos/foto_Control_Diario_A1_2026-03-10_03-01.jpg',
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
