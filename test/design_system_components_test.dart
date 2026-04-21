import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_web/design_system/components/components.dart';
import 'package:bitacora_web/design_system/colors.dart';
import 'package:bitacora_web/design_system/theme_data.dart';

Widget _wrap(Widget child, {bool dark = false}) => MaterialApp(
      theme: dark ? AppThemeBuilder.dark() : AppThemeBuilder.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('AppButton', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(_wrap(
        AppButton(label: 'Save', onPressed: () {}),
      ));
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('calls onPressed', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        AppButton(label: 'Go', onPressed: () => tapped = true),
      ));
      await tester.tap(find.text('Go'));
      expect(tapped, isTrue);
    });

    testWidgets('shows CircularProgressIndicator when loading', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppButton(label: 'Save', loading: true),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('destructive variant renders', (tester) async {
      await tester.pumpWidget(_wrap(
        AppButton(
          label: 'Delete',
          variant: AppButtonVariant.destructive,
          onPressed: () {},
        ),
      ));
      expect(find.text('Delete'), findsOneWidget);
    });
  });

  group('AppCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppCard(child: Text('Content')),
      ));
      expect(find.text('Content'), findsOneWidget);
    });

    testWidgets('tappable card calls onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        AppCard(child: const Text('Card'), onTap: () => tapped = true),
      ));
      await tester.tap(find.text('Card'));
      expect(tapped, isTrue);
    });
  });

  group('AppInput', () {
    testWidgets('renders with hint', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppInput(hint: 'Type here'),
      ));
      expect(find.text('Type here'), findsOneWidget);
    });

    testWidgets('calls onChanged', (tester) async {
      String? changed;
      await tester.pumpWidget(_wrap(
        AppInput(hint: 'Name', onChanged: (v) => changed = v),
      ));
      await tester.enterText(find.byType(TextField), 'hello');
      expect(changed, 'hello');
    });
  });

  group('AppListTile', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppListTile(title: 'Settings'),
      ));
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('renders subtitle', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppListTile(title: 'Profile', subtitle: 'View your info'),
      ));
      expect(find.text('View your info'), findsOneWidget);
    });

    testWidgets('calls onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        AppListTile(title: 'Tap me', onTap: () => tapped = true),
      ));
      await tester.tap(find.text('Tap me'));
      expect(tapped, isTrue);
    });

    testWidgets('shows chevron when showChevron=true', (tester) async {
      await tester.pumpWidget(_wrap(
        const AppListTile(title: 'Nav', showChevron: true),
      ));
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  group('AppText', () {
    testWidgets('AppText.body renders text', (tester) async {
      await tester.pumpWidget(_wrap(const AppText.body('Hello')));
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('AppText.headline uses 17pt / w600', (tester) async {
      await tester.pumpWidget(_wrap(const AppText.headline('Title')));
      final text = tester.widget<Text>(find.text('Title'));
      expect(text.style?.fontSize, 17);
      expect(text.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('AppSecondaryText uses secondaryLabel color in light mode',
        (tester) async {
      await tester.pumpWidget(_wrap(const AppSecondaryText('Sub')));
      final text = tester.widget<Text>(find.text('Sub'));
      final expected = AppColors.secondaryLabel(Brightness.light);
      expect(text.style?.color, expected);
    });

    testWidgets('AppText.caption2 is 11pt', (tester) async {
      await tester.pumpWidget(_wrap(const AppText.caption2('tiny')));
      final text = tester.widget<Text>(find.text('tiny'));
      expect(text.style?.fontSize, 11);
    });
  });
}
