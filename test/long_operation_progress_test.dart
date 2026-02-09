import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/services/sheet_store.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:bitacora_web/ui/app_strings.dart';
import 'package:bitacora_web/ui/loading_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('StartPage busy overlay hook supports cancel action',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
    });
    await SheetStore.init();

    tester.view.physicalSize = const Size(1700, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
        ),
      ),
    );
    await _pumpFrames(tester);

    final state = tester.state(find.byType(StartPage)) as dynamic;
    state.debugShowBusyOverlay(
      message: AppStrings.progressImportingBackup,
      canCancel: true,
    );
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(AppStrings.progressImportingBackup), findsOneWidget);

    final cancelInOverlay = find.descendant(
      of: find.byType(LoadingState),
      matching: find.text(AppStrings.cancel),
    );
    expect(cancelInOverlay, findsOneWidget);

    await tester.tap(cancelInOverlay);
    await tester.pump();

    expect(state.debugBusyCancelRequested(), isTrue);

    state.debugClearBusyOverlay();
    await tester.pump();
    expect(find.text(AppStrings.progressImportingBackup), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Editor operation overlay hook supports save/export variants',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    tester.view.physicalSize = const Size(1440, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: EditorScreen(sheetId: 'editor-progress-overlay'),
      ),
    );
    await tester.pump();

    final state = tester.state(find.byType(EditorScreen)) as dynamic;

    state.debugShowOperationProgress(
      message: AppStrings.progressSaving,
      cancellable: false,
    );
    await tester.pump();

    expect(find.byType(LoadingState), findsOneWidget);
    expect(find.text(AppStrings.progressSaving), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LoadingState),
        matching: find.text(AppStrings.cancel),
      ),
      findsNothing,
    );

    state.debugShowOperationProgress(
      message: AppStrings.progressPreparingExport,
      cancellable: true,
    );
    await tester.pump();

    final cancelInOverlay = find.descendant(
      of: find.byType(LoadingState),
      matching: find.text(AppStrings.cancel),
    );
    expect(cancelInOverlay, findsOneWidget);

    await tester.tap(cancelInOverlay);
    await tester.pump();

    expect(state.debugOperationCancelRequested(), isTrue);

    state.debugClearOperationProgress();
    await tester.pump();
    expect(find.text(AppStrings.progressPreparingExport), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _noop() {}
