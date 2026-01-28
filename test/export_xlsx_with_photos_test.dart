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

  String colLetter(int col) {
    var n = col;
    var out = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      out = String.fromCharCode(65 + rem) + out;
      n = (n - 1) ~/ 26;
    }
    return out;
  }

  String? cellText({
    required String sheetXml,
    required String cellRef,
    required List<String> sharedStrings,
  }) {
    final reg = RegExp(
      '<c[^>]*r="$cellRef"[^>]*>(.*?)</c>',
      dotAll: true,
    );
    final match = reg.firstMatch(sheetXml);
    if (match == null) return null;

    final cellXml = match.group(0) ?? '';
    final valueMatch = RegExp('<v>(.*?)</v>', dotAll: true).firstMatch(cellXml);
    if (valueMatch == null) return '';

    final raw = (valueMatch.group(1) ?? '').trim();
    if (raw.isEmpty) return '';

    final isShared = RegExp('t="s"').hasMatch(cellXml);
    if (isShared) {
      final idx = int.tryParse(raw);
      if (idx == null || idx < 0 || idx >= sharedStrings.length) return '';
      return sharedStrings[idx];
    }

    return '';
  }

  void expectNoPhotoTokens(String xml) {
    expect(xml.contains('.jpg'), isFalse);
    expect(xml.contains('.jpeg'), isFalse);
    expect(xml.contains('.png'), isFalse);
    expect(xml.contains('file:'), isFalse);
    expect(xml.contains('content://'), isFalse);
    expect(xml.contains('/storage/'), isFalse);
    expect(xml.contains('c:\\'), isFalse);
    expect(xml.contains('dcim'), isFalse);
    expect(xml.contains('img_'), isFalse);
    expect(xml.contains('camera_'), isFalse);
    expect(xml.contains('gallery_'), isFalse);
    expect(xml.contains('photo_'), isFalse);
    expect(xml.contains('embedded_'), isFalse);
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
      final file = archive.files
          .firstWhere((f) => f.name.replaceAll('\\', '/') == name);
      final xml = utf8.decode(file.content as List<int>);
      final embedIds = RegExp(r'r:embed="([^"]+)"')
          .allMatches(xml)
          .map((m) => m.group(1) ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      final relName =
          'xl/drawings/_rels/${name.split('/').last}.rels';
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

  void expectPhotoCellsState({
    required Archive archive,
    required List<int> photoCols,
    required List<int> rowsWithPhotos,
    required List<int> rowsWithMissing,
  }) {
    final sheet = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/') == 'xl/worksheets/sheet1.xml',
    );
    final xml = utf8.decode(sheet.content as List<int>);
    final sharedStrings = readSharedStrings(archive);

    for (final row in rowsWithPhotos) {
      for (final col in photoCols) {
        final ref = '${colLetter(col)}$row';
        final value = cellText(
          sheetXml: xml,
          cellRef: ref,
          sharedStrings: sharedStrings,
        );
        expect(value == null || value.isEmpty, isTrue);
      }
    }

    for (final row in rowsWithMissing) {
      for (final col in photoCols) {
        final ref = '${colLetter(col)}$row';
        final value = cellText(
          sheetXml: xml,
          cellRef: ref,
          sharedStrings: sharedStrings,
        );
        expect(value, 'N/D');
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

    final drawingFiles = names.where((n) => n.startsWith('xl/drawings/drawing'));
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
      final sharedXml =
          utf8.decode(shared.content as List<int>).toLowerCase();
      expectNoPhotoTokens(sharedXml);
    }

    final worksheetXmls = names.where(
      (n) => n.startsWith('xl/worksheets/') && !n.contains('_rels/'),
    );
    for (final name in worksheetXmls) {
      final file = archive.files
          .firstWhere((f) => f.name.replaceAll('\\', '/') == name);
      final xml = utf8.decode(file.content as List<int>).toLowerCase();
      expectNoPhotoTokens(xml);
    }

    final drawingXmls = names.where(
      (n) => n.startsWith('xl/drawings/drawing') && !n.contains('_rels/'),
    );
    for (final name in drawingXmls) {
      final file = archive.files
          .firstWhere((f) => f.name.replaceAll('\\', '/') == name);
      final xml = utf8.decode(file.content as List<int>).toLowerCase();
      expectNoPhotoTokens(xml);
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
      photosByRow: {
        0: [png],
        1: [Uint8List(0)],
        2: [png],
      },
    );

    expect(bytes, isNotEmpty);
    expectMediaAndDrawings(bytes);

    // buildXlsxWithPhotos: col 1 = '#', col 2 = 'Dato', col 3 = 'Foto 1'
    expectPhotoCellsState(
      archive: ZipDecoder().decodeBytes(bytes),
      photoCols: const [3],
      rowsWithPhotos: const [2, 4],
      rowsWithMissing: const [3],
    );
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

    expect(resolved, isNotNull);
    expect(resolved!.isNotEmpty, isTrue);

    final bytes = await buildXlsxWithPhotos(
      columns: const ['Dato'],
      rows: const [
        ['fila 1'],
      ],
      photosByRow: {
        0: [resolved],
      },
    );

    expectMediaAndDrawings(bytes);
  });

  test('generate sample XLSX with photos for manual review', () async {
    final png = makeTinyPng();
    final stamp = DateTime.utc(2026, 1, 1, 12);

    final bytes = await buildXlsxWithPhotos(
      columns: const ['Dato'],
      rows: const [
        ['fila 1'],
        ['fila 2'],
        ['fila 3'],
      ],
      photosByRow: {
        0: [png],
        1: [png],
        2: [png],
      },
      photoMeta: [
        PhotoMeta(
          rowIndex: 0,
          colIndex: 0,
          photoIndex: 0,
          addedAt: stamp,
          sourceLabel: '',
        ),
        PhotoMeta(
          rowIndex: 1,
          colIndex: 0,
          photoIndex: 0,
          addedAt: stamp,
          sourceLabel: '',
        ),
        PhotoMeta(
          rowIndex: 2,
          colIndex: 0,
          photoIndex: 0,
          addedAt: stamp,
          sourceLabel: '',
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

