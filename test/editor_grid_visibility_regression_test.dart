import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('template deep link renders visible grid root', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: buildRootPageForUri(
          uri: Uri.parse('https://example.com/?template=campo'),
          isLight: true,
          onToggleTheme: _noop,
          firebaseOk: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-grid-root')), findsOneWidget);

    final state = tester.state(find.byType(EditorScreen)) as dynamic;
    expect(state.debugRowCount, greaterThan(0));
  });
}

void _noop() {}
