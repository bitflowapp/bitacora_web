import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_web/design_system/components/components.dart';
import 'package:bitacora_web/design_system/theme_data.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppThemeBuilder.light(),
      home: child,
    );

void main() {
  group('AppAppBar', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        appBar: const AppAppBar(title: 'My Screen'),
        body: const SizedBox(),
      )));
      expect(find.text('My Screen'), findsOneWidget);
    });

    testWidgets('preferredSize height is kToolbarHeight', (tester) async {
      const bar = AppAppBar(title: 'Test');
      expect(bar.preferredSize.height, kToolbarHeight);
    });

    testWidgets('renders actions', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        appBar: AppAppBar(
          title: 'Screen',
          actions: [IconButton(icon: const Icon(Icons.add), onPressed: () {})],
        ),
        body: const SizedBox(),
      )));
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });

  group('showAppBottomSheet', () {
    testWidgets('shows child content', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => showAppBottomSheet(
              context: ctx,
              child: const Text('Sheet Content'),
            ),
            child: const Text('Open'),
          );
        }),
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet Content'), findsOneWidget);
    });

    testWidgets('shows title when provided', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => showAppBottomSheet(
              context: ctx,
              title: 'Options',
              child: const Text('Items'),
            ),
            child: const Text('Open'),
          );
        }),
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Options'), findsOneWidget);
    });
  });

  group('AppModalDialog', () {
    testWidgets('renders title and content', (tester) async {
      await tester.pumpWidget(_wrap(Scaffold(
        body: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => showAppModal(
              context: ctx,
              title: 'Confirm',
              content: const Text('Are you sure?'),
            ),
            child: const Text('Open'),
          );
        }),
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Are you sure?'), findsOneWidget);
    });

    testWidgets('action button calls onPressed and closes dialog',
        (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(Scaffold(
        body: Builder(builder: (ctx) {
          return ElevatedButton(
            onPressed: () => showAppModal(
              context: ctx,
              title: 'Delete?',
              content: const Text('This cannot be undone.'),
              actions: [
                AppModalAction(
                  label: 'Delete',
                  isDestructive: true,
                  onPressed: () => called = true,
                ),
              ],
            ),
            child: const Text('Open'),
          );
        }),
      )));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(find.text('Delete?'), findsNothing);
    });
  });
}
