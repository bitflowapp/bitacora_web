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
    // Resumen ejecutivo: secciones presentes y metricas tabuladas en col B.
    expect(sharedValues, contains('Resumen ejecutivo'));
    expect(sharedValues, contains('Totales generales'));
    expect(sharedValues, contains('Calidad del relevamiento'));
    expect(sharedValues, contains('Advertencias'));
    expect(sharedValues, contains('Filas exportadas'));
    expect(sharedValues, contains('Filas con evidencias'));
    expect(summaryXml.contains('r="B5"'), isTrue);

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

  test('generate sample bundle (xlsx + zip) for manual review', () async {
    final png = makeTinyPng();
    final xlsxBytes = await buildXlsxWithPhotos(
      columns: const ['Fecha', 'Estado', 'Foto / Evidencia', 'Observaciones'],
      rows: const [
        ['01/05/2026', 'OK', '', 'Inspeccion preliminar'],
        ['02/05/2026', 'Observado', '', 'Falta tornillos'],
        ['03/05/2026', 'Crítico', '', 'Reemplazar valvula'],
      ],
      embeddedPhotos: [
        EmbeddedPhoto(rowIndex: 0, colIndex: 2, bytes: png),
      ],
      attachments: const [
        AttachmentRow(
          cellRef: 'C1',
          type: 'photo',
          fileName: 'C1_p1_evidencia.jpg',
          notes: 'Vista general',
          relativePath: 'attachments/photos/C1_p1_evidencia.jpg',
        ),
        AttachmentRow(
          cellRef: 'C2',
          type: 'video',
          fileName: 'C2_p1_video.mov',
          notes: 'Detalle de torque',
          relativePath: 'attachments/video/C2_p1_video.mov',
        ),
        AttachmentRow(
          cellRef: 'C3',
          type: 'audio',
          fileName: 'C3_p1_voz.m4a',
          notes: '',
          relativePath: 'attachments/audio/C3_p1_voz.m4a',
        ),
      ],
      includeIndexColumn: false,
      includeCoverSheet: true,
      includeSummarySheet: true,
      inZip: true,
      projectMeta: ExportProjectMeta(
        title: 'Relevamiento bombas Norte',
        obra: 'Planta Norte',
        cliente: 'AcmeOil S.A.',
        responsable: 'Tec. Lopez',
        ubicacion: 'Comodoro, Chubut',
        appVersion: '1.3.1',
        sheetId: 'sample-sheet-id',
        exportedAt: DateTime(2026, 5, 2, 10, 30),
        bundleNote:
            'Las evidencias viajan junto al XLSX dentro del paquete .zip.',
      ),
    );

    final dir = Directory('build/exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final xlsxFile = File('build/exports/sample_bundle.xlsx');
    xlsxFile.writeAsBytesSync(xlsxBytes, flush: true);

    // Empaquetar en un ZIP minimo simulando el flujo real (sin cargar bytes
    // reales, solo placeholders por archivo) para verificar la estructura.
    final archive = Archive()
      ..addFile(ArchiveFile('export.xlsx', xlsxBytes.length, xlsxBytes))
      ..addFile(ArchiveFile(
        'attachments/photos/C1_p1_evidencia.jpg',
        png.length,
        png,
      ))
      ..addFile(ArchiveFile(
        'attachments/video/C2_p1_video.mov',
        png.length,
        png,
      ))
      ..addFile(ArchiveFile(
        'attachments/audio/C3_p1_voz.m4a',
        png.length,
        png,
      ));
    final zipBytes = ZipEncoder().encode(archive);
    final zipFile = File('build/exports/sample_bundle.zip');
    zipFile.writeAsBytesSync(zipBytes, flush: true);

    expect(xlsxFile.existsSync(), isTrue);
    expect(zipFile.existsSync(), isTrue);

    // Verificar que el ZIP contiene el XLSX y carpetas de evidencias.
    final reread = ZipDecoder().decodeBytes(zipBytes);
    final entries = reread.files
        .map((f) => f.name.replaceAll('\\', '/'))
        .toList(growable: false);
    expect(entries, contains('export.xlsx'));
    expect(entries, contains('attachments/photos/C1_p1_evidencia.jpg'));
    expect(entries, contains('attachments/video/C2_p1_video.mov'));
    expect(entries, contains('attachments/audio/C3_p1_voz.m4a'));
  });

  test('Caratula renders project metadata with premium layout', () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Dato'],
      rows: const [
        ['fila 1'],
      ],
      includeIndexColumn: false,
      includeCoverSheet: true,
      includeSummarySheet: true,
      projectMeta: const ExportProjectMeta(
        title: 'Relevamiento Loma Negra',
        obra: 'Planta Cementera Loma',
        cliente: 'Loma Negra S.A.',
        responsable: 'Ing. Perez',
        ubicacion: 'Olavarria, Buenos Aires',
        appVersion: '1.3.1',
        sheetId: 'sheet-abc-123',
      ),
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final sharedValues = sharedStringValues(archive);

    expect(sharedValues, contains('Bit Flow'));
    expect(sharedValues, contains('Relevamiento Loma Negra'));
    expect(sharedValues, contains('Datos del proyecto'));
    expect(sharedValues, contains('Resumen del archivo'));
    expect(sharedValues, contains('Trazabilidad'));
    expect(sharedValues, contains('Planta Cementera Loma'));
    expect(sharedValues, contains('Loma Negra S.A.'));
    expect(sharedValues, contains('Ing. Perez'));
    expect(sharedValues, contains('Olavarria, Buenos Aires'));
    expect(sharedValues, contains('sheet-abc-123'));
    // Sin evidencias => deberian aparecer advertencias por cliente/obra/etc.
    // Aqui los datos estan completos asi que no deberia faltar cliente/obra/responsable.
    expect(sharedValues, contains('Sin advertencias. Relevamiento completo.'));
    // Caratula no debe usar el placeholder cuando los datos llegan completos.
    expect(sharedValues, isNot(contains('No especificado')));
  });

  test('Caratula muestra placeholders elegantes con meta vacia', () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Dato'],
      rows: const [
        ['fila 1'],
      ],
      includeIndexColumn: false,
      includeCoverSheet: true,
      includeSummarySheet: true,
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final sharedValues = sharedStringValues(archive);

    expect(sharedValues, contains('No especificado'));
    expect(sharedValues, contains('Falta indicar el cliente en la caratula.'));
    expect(sharedValues, contains('Falta indicar la obra en la caratula.'));
    expect(
      sharedValues,
      contains('Falta indicar el responsable del relevamiento.'),
    );
  });

  test('Adjuntos en modo ZIP genera hyperlinks "Abrir evidencia"', () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Dato'],
      rows: const [
        ['fila 1'],
        ['fila 2'],
      ],
      attachments: const [
        AttachmentRow(
          cellRef: 'A1',
          type: 'photo',
          fileName: 'A1_p1_foto.jpg',
          notes: 'Foto de portada',
          relativePath: 'attachments/photos/A1_p1_foto.jpg',
        ),
        AttachmentRow(
          cellRef: 'A2',
          type: 'video',
          fileName: 'A2_p1_video.mov',
          notes: '',
          relativePath: 'attachments/video/A2_p1_video.mov',
        ),
      ],
      includeIndexColumn: false,
      inZip: true,
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final sharedValues = sharedStringValues(archive);
    final names = archive.files
        .map((f) => f.name.replaceAll('\\', '/'))
        .toList(growable: false);

    expect(sharedValues, contains('Adjuntos del relevamiento'));
    expect(sharedValues, contains('Abrir evidencia'));
    expect(sharedValues, contains('attachments/photos/A1_p1_foto.jpg'));
    expect(sharedValues, contains('attachments/video/A2_p1_video.mov'));
    expect(sharedValues, contains('Foto de portada'));

    // El XLSX debe declarar al menos un hyperlink en la hoja Adjuntos.
    final adjuntosXml = readArchiveText(archive, 'xl/worksheets/sheet2.xml');
    expect(adjuntosXml.contains('<hyperlinks>'), isTrue);
    expect(adjuntosXml.contains('</hyperlinks>'), isTrue);

    // Y debe haber rels apuntando a los archivos relativos.
    final relsName = names.firstWhere(
      (n) => n == 'xl/worksheets/_rels/sheet2.xml.rels',
      orElse: () => '',
    );
    expect(relsName.isNotEmpty, isTrue,
        reason: 'Faltan relationships para hyperlinks de Adjuntos');
    final relsXml = readArchiveText(archive, relsName);
    expect(relsXml.contains('TargetMode="External"'), isTrue,
        reason: 'Los hyperlinks deben declararse como external');
    // Los nombres de archivo deben aparecer en los rels (encoded o no).
    expect(relsXml.contains('A1_p1_foto.jpg'), isTrue);
    expect(relsXml.contains('A2_p1_video.mov'), isTrue);
  });

  test('Adjuntos sin ZIP avisa que hay que exportar el paquete', () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Dato'],
      rows: const [
        ['fila 1'],
      ],
      attachments: const [
        AttachmentRow(
          cellRef: 'A1',
          type: 'video',
          fileName: 'A1_p1_video.mov',
          notes: '',
          relativePath: 'attachments/video/A1_p1_video.mov',
        ),
      ],
      includeIndexColumn: false,
      includeSummarySheet: true,
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final sharedValues = sharedStringValues(archive);

    // No debe haber hyperlink "Abrir evidencia" en standalone.
    expect(sharedValues, isNot(contains('Abrir evidencia')));
    expect(sharedValues, contains('Solo en paquete .zip'));
    // Resumen incluye advertencia por evidencias fuera del paquete.
    expect(
      sharedValues.any((v) => v.contains('paquete .zip')),
      isTrue,
    );
  });

  test('_BITFLOW_META sigue siendo invisible en el workbook', () async {
    final bytes = await buildXlsxWithPhotos(
      columns: const ['Dato'],
      rows: const [
        ['fila 1'],
      ],
      includeIndexColumn: false,
      includeCoverSheet: true,
      includeSummarySheet: true,
    );

    final archive = ZipDecoder().decodeBytes(bytes);
    final workbookXml = readArchiveText(archive, 'xl/workbook.xml');
    // Buscar la entrada <sheet ...> con name="_BITFLOW_META" y verificar
    // que tambien declara state="hidden" sin depender del orden de atributos.
    final entry = RegExp(
      r'<sheet\s[^>]*\bname="_BITFLOW_META"[^>]*/?>',
      caseSensitive: false,
    ).firstMatch(workbookXml);
    expect(entry, isNotNull,
        reason: 'workbook.xml debe declarar la hoja _BITFLOW_META');
    expect(entry!.group(0)!.contains('state="hidden"'), isTrue,
        reason: '_BITFLOW_META debe permanecer oculta');
  });
}
