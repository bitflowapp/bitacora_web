import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('warns before leaving when there are draft-only changes',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const ValueKey('open-editor-route'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const EditorScreen(
                          sheetId: 'unsaved-draft-exit-guardrail',
                          initialHeaders: <String>['Columna', 'Fotos'],
                          initialRows: <List<String>>[
                            <String>['valor base', ''],
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-editor-route')));
    await tester.pumpAndSettle();
    expect(find.byType(EditorScreen), findsOneWidget);

    final dynamic state = tester.state(find.byType(EditorScreen));
    state.debugSetCellDraft(0, 0, 'borrador sin commit');
    await tester.pump();

    await Navigator.of(state.context).maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Cambios sin guardar'), findsOneWidget);
    expect(find.byType(EditorScreen), findsOneWidget);
  });
}
