import 'package:bitacora_web/features/editor/editor_screen.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<dynamic> pumpMobileEditor(
    WidgetTester tester, {
    List<String>? headers,
    List<List<String>>? rows,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(
          sheetId: 'mobile-cta-discipline-test',
          initialHeaders: headers ?? <String>['Fecha', 'Estado', 'Fotos'],
          initialRows: rows ??
              <List<String>>[
                <String>['2026-03-18', 'Pendiente', ''],
              ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.state(find.byType(EditorScreen)) as dynamic;
  }

  testWidgets(
      'mobile header menu keeps core sales CTAs first and hides secondary ones',
      (tester) async {
    await pumpMobileEditor(tester);

    await tester.tap(find.byTooltip('Opciones').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('Foto + registro'), findsOneWidget);
    expect(find.text('Editar fila'), findsOneWidget);
    expect(find.text('Exportar / compartir'), findsOneWidget);
    expect(find.text('Acciones por lote'), findsNothing);
    expect(find.text('Evidencia de la celda'), findsNothing);

    await tester.tap(find.text('Opciones avanzadas'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Acciones por lote'),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Acciones por lote'), findsOneWidget);
    expect(find.text('Evidencia de la celda'), findsOneWidget);
  });

  testWidgets('mobile overflow uses honest media CTAs', (tester) async {
    final state = await pumpMobileEditor(tester);

    state.debugOpenMobileEditorForCell(0, 0);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mas acciones').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('Guardar y cerrar'), findsOneWidget);
    expect(find.text('Adjuntar foto en esta celda'), findsOneWidget);
    expect(find.text('Adjuntar video en esta celda'), findsOneWidget);
    expect(find.text('Adjuntar archivo en esta celda'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Adjuntar GPS en esta celda'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Adjuntar GPS en esta celda'), findsOneWidget);
    expect(find.text('Ajuste de GPS'), findsOneWidget);
    expect(find.text('Fotos de esta celda'), findsNothing);
    expect(find.text('GPS -> Pegar en esta celda'), findsNothing);
    expect(find.text('Modo GPS...'), findsNothing);
  });

  testWidgets('critical mobile controls keep 44pt minimum hit targets',
      (tester) async {
    final state = await pumpMobileEditor(tester);

    final optionsSize = tester.getSize(
      find.byKey(const ValueKey('mobile-header-options-button'))
          .hitTestable()
          .last,
    );
    expect(optionsSize.width, greaterThanOrEqualTo(44));
    expect(optionsSize.height, greaterThanOrEqualTo(44));

    final fabSize = tester.getSize(find.byKey(const ValueKey('mobile-fab-main')));
    expect(fabSize.width, greaterThanOrEqualTo(44));
    expect(fabSize.height, greaterThanOrEqualTo(44));

    state.debugOpenMobileEditorForCell(0, 0);
    await tester.pumpAndSettle();

    final saveSize = tester.getSize(
      find.byKey(const ValueKey('mobile-inline-save-button'))
          .hitTestable()
          .last,
    );
    expect(saveSize.width, greaterThanOrEqualTo(44));
    expect(saveSize.height, greaterThanOrEqualTo(44));
  });

  testWidgets('mobile editor uses natural input for notes and strict input for technical fields',
      (tester) async {
    final state = await pumpMobileEditor(
      tester,
      headers: <String>['Observaciones', 'Codigo', 'Fotos'],
      rows: <List<String>>[
        <String>['revisar tapa', 'AB-17', ''],
      ],
    );

    Finder currentField() => find.descendant(
          of: find.byKey(const ValueKey('mobileInlineEditorField')),
          matching: find.byType(TextField),
        );

    state.debugOpenMobileEditorForCell(0, 0);
    await tester.pumpAndSettle();

    var textField = tester.widget<TextField>(currentField());
    expect(textField.autocorrect, isTrue);
    expect(textField.enableSuggestions, isTrue);
    expect(textField.textCapitalization, TextCapitalization.sentences);
    expect(textField.smartDashesType, SmartDashesType.enabled);
    expect(textField.smartQuotesType, SmartQuotesType.enabled);

    state.debugOpenMobileEditorForCell(0, 1);
    await tester.pumpAndSettle();

    textField = tester.widget<TextField>(currentField());
    expect(textField.autocorrect, isFalse);
    expect(textField.enableSuggestions, isFalse);
    expect(textField.textCapitalization, TextCapitalization.none);
    expect(textField.smartDashesType, SmartDashesType.disabled);
    expect(textField.smartQuotesType, SmartQuotesType.disabled);
  });

  testWidgets('opening mobile overflow dismisses the keyboard before the sheet',
      (tester) async {
    final state = await pumpMobileEditor(
      tester,
      headers: <String>['Observaciones', 'Estado', 'Fotos'],
      rows: <List<String>>[
        <String>['nota breve', 'Pendiente', ''],
      ],
    );

    state.debugOpenMobileEditorForCell(0, 0);
    await tester.pumpAndSettle();

    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byTooltip('Mas acciones').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('Mas acciones'), findsOneWidget);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('persistent closeout hides competing mobile layers',
      (tester) async {
    final state = await pumpMobileEditor(tester);

    await state.debugSetFieldMode(true);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('flowbot-inline-bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-fab-main')), findsOneWidget);

    state.debugSetExportHooks(
      shareHook: (_) async => throw UnsupportedError('share not supported'),
      saveLocationHook: ({
        required String suggestedName,
        required List<XTypeGroup> acceptedTypeGroups,
      }) async =>
          const FileSaveLocation('/tmp/mobile/control.xlsx'),
      saveFileHook: (_, __) async {},
      persistShareTempFileHook: ({
        required String fileName,
        required bytes,
      }) async =>
          null,
    );

    await state.debugRunExportSaveFlowForTest(
      name: 'control.xlsx',
      mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      share: false,
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('export-flow-result-banner')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('flowbot-inline-bar')), findsNothing);
    expect(
      find.byKey(const ValueKey('mobile-fab-main')).hitTestable(),
      findsNothing,
    );
  });
}
