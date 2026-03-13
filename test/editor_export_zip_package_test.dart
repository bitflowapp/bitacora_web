import 'package:archive/archive.dart';
import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('zip bundle includes xlsx pdf manifest sheet readme and folders',
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

    await tester.pumpAndSettle(const Duration(milliseconds: 800));

    final dynamic state = tester.state(find.byType(EditorScreen));
    final bytes = await state.debugBuildZipBundleBytesForTest();
    expect(bytes, isNotNull);
    expect(bytes, isNotEmpty);

    final archive = ZipDecoder().decodeBytes(bytes!);
    final names =
        archive.files.map((f) => f.name.replaceAll('\\', '/')).toSet();

    expect(names.contains('BitFlow_Control_Diario.xlsx'), isTrue);
    expect(names.contains('BitFlow_Control_Diario.pdf'), isTrue);

    expect(names.contains('manifest.json'), isTrue);
    expect(names.contains('sheet.json'), isTrue);
    expect(names.contains('README.txt'), isTrue);

    expect(names.contains('evidencias/'), isTrue);
    expect(names.contains('evidencias/fotos/'), isTrue);
    expect(names.contains('evidencias/videos/'), isTrue);
    expect(names.contains('evidencias/audio/'), isTrue);
  });
}
