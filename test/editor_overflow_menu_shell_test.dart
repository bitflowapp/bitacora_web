import 'package:bitacora_web/features/editor/widgets/editor_overflow_menu_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows explicit X and closes when tapped', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (ctx) => EditorOverflowMenuShell(
                    title: 'Opciones',
                    onClose: () => Navigator.of(ctx).pop(),
                    child: Column(
                      children: List<Widget>.generate(
                        30,
                        (i) => ListTile(title: Text('Item $i')),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-more-close-x')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor-more-close-x')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-more-close-x')), findsNothing);
  });

  testWidgets('keeps content scrollable on small viewport without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 520);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorOverflowMenuShell(
            title: 'Opciones',
            onClose: () {},
            child: Column(
              children: List<Widget>.generate(
                40,
                (i) => ListTile(title: Text('Elemento $i')),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-more-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
