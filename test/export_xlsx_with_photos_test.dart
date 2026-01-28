import 'dart:convert';
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

  void expectNoPhotoTokens(String xml) {
    expect(xml.contains('.jpg'), isFalse);
    expect(xml.contains('.jpeg'), isFalse);
    expect(xml.contains('.png'), isFalse);
    expect(xml.contains('file:'), isFalse);
    expect(xml.contains('/storage/'), isFalse);
    expect(xml.contains('c:\\'), isFalse);
    expect(xml.contains('img_'), isFalse);
    expect(xml.contains('camera_'), isFalse);
    expect(xml.contains('gallery_'), isFalse);
    expect(xml.contains('photo_'), isFalse);
    expect(xml.contains('embedded_'), isFalse);
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

    final relName = drawingRelFiles.first;
    final relFile = archive.files
        .firstWhere((f) => f.name.replaceAll('\\', '/') == relName);
    final relXml = utf8.decode(relFile.content as List<int>);
    expect(relXml.contains('image'), isTrue);

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
        1: [png],
        2: [png],
      },
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
}
