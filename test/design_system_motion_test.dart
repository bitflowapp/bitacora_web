import 'package:bitacora_web/design_system/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('AppPressable scales down while pressed', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const Center(
          child: AppPressable(
            child: SizedBox.square(dimension: 80),
          ),
        ),
      ),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(AppPressable)));
    await tester.pump(const Duration(milliseconds: 80));

    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.scale, lessThan(1));

    await gesture.up();
    await tester.pumpAndSettle();
    final settled = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(settled.scale, 1);
  });

  testWidgets('AppMotionStaggered reveals every child', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AppMotionStaggered(
          children: [
            Text('Uno'),
            Text('Dos'),
            Text('Tres'),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Uno'), findsOneWidget);
    expect(find.text('Dos'), findsOneWidget);
    expect(find.text('Tres'), findsOneWidget);
    expect(find.byType(AppMotionReveal), findsNWidgets(3));
  });
}
