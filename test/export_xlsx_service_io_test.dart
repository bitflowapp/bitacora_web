import 'dart:io';

import 'package:bitacora_web/services/export_xlsx_service.dart';
import 'package:flutter_test/flutter_test.dart';
// Test-only access to the platform interface lets us avoid a device channel.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late PathProviderPlatform originalPathProvider;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bitflow_xlsx_export_');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'ExportXlsxService.download writes an XLSX file on IO platforms',
    () async {
      await ExportXlsxService.download(
        fileName: 'Planilla Campo',
        headers: const <String>['Equipo', 'Estado'],
        rows: const <List<String>>[
          <String>['Bomba P-101', 'OK'],
        ],
      );

      final files = tempDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.xlsx'))
          .toList(growable: false);

      expect(files, hasLength(1));
      expect(files.single.path, endsWith('Planilla Campo.xlsx'));
      expect(await files.single.length(), greaterThan(0));
    },
  );

  test(
    'ExportXlsxService.download caps long filenames on IO platforms',
    () async {
      final longName = List<String>.filled(90, 'Obra Norte').join(' ');

      await ExportXlsxService.download(
        fileName: '$longName:/?*.xlsx',
        headers: const <String>['Equipo'],
        rows: const <List<String>>[
          <String>['Bomba P-101'],
        ],
      );

      final files = tempDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.xlsx'))
          .toList(growable: false);

      expect(files, hasLength(1));
      final fileName = files.single.path.split(Platform.pathSeparator).last;
      expect(fileName.length, lessThanOrEqualTo(125));
      expect(fileName, isNot(contains(':')));
      expect(fileName, isNot(contains('?')));
      expect(fileName, isNot(contains('*')));
      expect(await files.single.length(), greaterThan(0));
    },
  );
}

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getDownloadsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}
