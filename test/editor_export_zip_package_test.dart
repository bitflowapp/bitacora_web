// ignore_for_file: depend_on_referenced_packages

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Hive.init('./build/test_hive_zip');
    AudioplayersPlatformInterface.instance = _FakeAudioPlatform();
    GlobalAudioplayersPlatformInterface.instance = _FakeGlobalAudioPlatform();
  });

  tearDownAll(() async {
    await Hive.close();
  });

  testWidgets('zip package includes workbook, report and manifest metadata',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditorScreen(
            sheetId: 'zip_package_sheet',
            initialName: 'Control Diario',
            initialHeaders: <String>['Actividad', 'Estado'],
            initialRows: <List<String>>[
              <String>['Inspeccion', 'OK'],
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 900));

    final dynamic state = tester.state(find.byType(EditorScreen));
    final zipBytes = await tester.runAsync(() {
      return state.debugBuildZipBundleBytesForTest(
        includeAttachments: true,
      );
    });

    expect(zipBytes, isNotNull);
    final archive = ZipDecoder().decodeBytes(zipBytes!);
    final names =
        archive.files.map((f) => f.name.replaceAll('\\', '/')).toSet();

    expect(names.contains('manifest.json'), isTrue);
    expect(names.contains('sheet.json'), isTrue);
    expect(names.any((name) => name.endsWith('.xlsx')), isTrue);
    expect(names.any((name) => name.endsWith('.pdf')), isTrue);

    final manifestFile = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/') == 'manifest.json',
    );
    final manifest = jsonDecode(
      utf8.decode(manifestFile.content as List<int>),
    ) as Map<String, dynamic>;
    final package = manifest['package'] as Map<String, dynamic>;
    expect((package['workbook'] ?? '').toString().endsWith('.xlsx'), isTrue);
    expect(
      (package['report'] ?? '').toString().endsWith('.pdf'),
      isTrue,
    );
    expect(
      package['evidencePaths'],
      equals(<String>[
        'evidencias/fotos',
        'evidencias/videos',
        'evidencias/audio'
      ]),
    );

    final pdfEntry = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/').endsWith('.pdf'),
    );
    final pdfBytes = pdfEntry.content as List<int>;
    expect(utf8.decode(pdfBytes.take(4).toList()), equals('%PDF'));

    final readmeFile = archive.files.firstWhere(
      (f) => f.name.replaceAll('\\', '/') == 'README.txt',
    );
    final readme = utf8.decode(readmeFile.content as List<int>);
    expect(readme.contains('Uso recomendado:'), isTrue);
    expect(readme.contains('Abrir primero el PDF'), isTrue);
  });
}

class _FakeAudioPlatform extends AudioplayersPlatformInterface {
  @override
  Future<void> create(String playerId) async {}

  @override
  Future<void> dispose(String playerId) async {}

  @override
  Future<void> pause(String playerId) async {}

  @override
  Future<void> stop(String playerId) async {}

  @override
  Future<void> resume(String playerId) async {}

  @override
  Future<void> release(String playerId) async {}

  @override
  Future<void> seek(String playerId, Duration position) async {}

  @override
  Future<void> setBalance(String playerId, double balance) async {}

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<void> setReleaseMode(String playerId, ReleaseMode releaseMode) async {}

  @override
  Future<void> setPlaybackRate(String playerId, double playbackRate) async {}

  @override
  Future<void> setSourceUrl(
    String playerId,
    String url, {
    bool? isLocal,
    String? mimeType,
  }) async {}

  @override
  Future<void> setSourceBytes(
    String playerId,
    Uint8List bytes, {
    String? mimeType,
  }) async {}

  @override
  Future<void> setAudioContext(
      String playerId, AudioContext audioContext) async {}

  @override
  Future<void> setPlayerMode(String playerId, PlayerMode playerMode) async {}

  @override
  Future<int?> getDuration(String playerId) async => 0;

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<void> emitLog(String playerId, String message) async {}

  @override
  Future<void> emitError(String playerId, String code, String message) async {}

  @override
  Stream<AudioEvent> getEventStream(String playerId) =>
      const Stream<AudioEvent>.empty();
}

class _FakeGlobalAudioPlatform extends GlobalAudioplayersPlatformInterface {
  @override
  Future<void> init() async {}

  @override
  Future<void> setGlobalAudioContext(AudioContext ctx) async {}

  @override
  Future<void> emitGlobalLog(String message) async {}

  @override
  Future<void> emitGlobalError(String code, String message) async {}

  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() =>
      const Stream<GlobalAudioEvent>.empty();
}
