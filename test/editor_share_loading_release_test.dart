import 'dart:async';

import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:bitacora_web/ui/app_strings.dart';
import 'package:bitacora_web/ui/loading_state.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpEditor(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EditorScreen(
            sheetId: 'share_loading_sheet',
            initialName: 'Control Diario',
            initialHeaders: <String>['Actividad', 'Estado'],
            initialRows: <List<String>>[
              <String>['Inspeccion', 'OK'],
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle(const Duration(milliseconds: 700));
    return tester.state(find.byType(EditorScreen));
  }

  Future<void> pumpUntilFutureCompletes(
    WidgetTester tester,
    Future<void> future, {
    int maxTicks = 120,
    Duration tick = const Duration(milliseconds: 100),
  }) async {
    var completed = false;
    Object? error;
    StackTrace? stack;
    future.then<void>((_) {
      completed = true;
    }, onError: (Object e, StackTrace st) {
      error = e;
      stack = st;
      completed = true;
    });

    for (var i = 0; i < maxTicks && !completed; i++) {
      await tester.pump(tick);
    }

    if (!completed) {
      fail('La operación de share no terminó en el tiempo esperado.');
    }
    if (error != null) {
      Error.throwWithStackTrace(error!, stack ?? StackTrace.current);
    }
    await tester.pumpAndSettle();
  }

  Future<void> runShareFlow(dynamic state) {
    return state.debugRunExportSaveFlowWithProgressForTest(
      name: 'control_diario.xlsx',
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      share: true,
    );
  }

  testWidgets('share success libera loading', (tester) async {
    final dynamic state = await pumpEditor(tester);
    state.debugSetExportHooks(
      shareHook: (_) async => Future<void>.delayed(
        const Duration(milliseconds: 150),
      ),
      persistShareTempFileHook:
          ({required String fileName, required bytes}) async => null,
    );

    final future = runShareFlow(state);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(LoadingState), findsOneWidget);

    await pumpUntilFutureCompletes(tester, future);

    expect(find.byType(LoadingState), findsNothing);
    expect(state.debugLastErrorFeedbackMessage(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('share cancelado por proveedor libera loading', (tester) async {
    final dynamic state = await pumpEditor(tester);
    state.debugSetExportHooks(
      shareHook: (_) async => throw Exception('share cancelled by user'),
      saveLocationHook: ({
        required String suggestedName,
        required List<XTypeGroup> acceptedTypeGroups,
      }) async =>
          null,
      persistShareTempFileHook:
          ({required String fileName, required bytes}) async => null,
    );

    final future = runShareFlow(state);
    await pumpUntilFutureCompletes(tester, future);

    expect(find.byType(LoadingState), findsNothing);
    expect(state.debugLastToastMessage(), contains('Compartir cancelado'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar corta share colgado y libera loading', (tester) async {
    final dynamic state = await pumpEditor(tester);
    final hanging = Completer<void>();

    state.debugSetExportHooks(
      shareHook: (_) => hanging.future,
      saveLocationHook: ({
        required String suggestedName,
        required List<XTypeGroup> acceptedTypeGroups,
      }) async =>
          null,
      persistShareTempFileHook:
          ({required String fileName, required bytes}) async => null,
    );

    final future = runShareFlow(state);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.byType(LoadingState), findsOneWidget);

    final cancelInOverlay = find.descendant(
      of: find.byType(LoadingState),
      matching: find.text(AppStrings.cancel),
    );
    expect(cancelInOverlay, findsOneWidget);

    await tester.tap(cancelInOverlay);
    await tester.pump(const Duration(milliseconds: 220));

    await pumpUntilFutureCompletes(tester, future);

    expect(find.byType(LoadingState), findsNothing);
    expect(state.debugLastToastMessage(), contains('Compartir cancelado'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('fallback de share libera loading y da feedback claro',
      (tester) async {
    final dynamic state = await pumpEditor(tester);
    state.debugSetExportHooks(
      shareHook: (_) async => throw UnsupportedError('share not supported'),
      saveLocationHook: ({
        required String suggestedName,
        required List<XTypeGroup> acceptedTypeGroups,
      }) async =>
          const FileSaveLocation('/tmp/share-fallback.xlsx'),
      saveFileHook: (_, __) async {},
      persistShareTempFileHook:
          ({required String fileName, required bytes}) async => null,
    );

    final future = runShareFlow(state);
    await pumpUntilFutureCompletes(tester, future);

    expect(find.byType(LoadingState), findsNothing);
    expect(
      state.debugLastToastMessage(),
      contains('No pudimos abrir la opción de compartir el XLSX'),
    );
    expect(tester.takeException(), isNull);
  });
}
