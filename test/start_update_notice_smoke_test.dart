import 'package:bitacora_web/services/app_update_service.dart';
import 'package:bitacora_web/start_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('StartPage shows update notice when update is available',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'bitflow.onboarding_done.v1': true,
      'bitflow.demo_mode_enabled.v1': true,
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: StartPage(
          isLight: true,
          onToggleTheme: _noop,
          updateService: _FakeUpdateService(),
        ),
      ),
    );

    await _pumpFrames(tester);

    expect(find.text('Actualización 9.9.9 disponible.'), findsOneWidget);
    expect(find.text('Descargar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeUpdateService extends AppUpdateService {
  const _FakeUpdateService();

  @override
  Future<AppUpdateSnapshot> checkForUpdates({String? sourceUrl}) async {
    return AppUpdateSnapshot(
      requestOk: true,
      checkedAt: DateTime.now(),
      sourceUri: Uri.parse(sourceUrl ?? 'https://example.test/version.json'),
      localVersion: '1.0.0',
      localBuildNumber: '1',
      localBuildId: 'build-local',
      remoteVersion: '9.9.9',
      remoteBuildId: 'build-remote',
      updateAvailable: true,
      message: 'Actualización disponible.',
    );
  }
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

void _noop() {}
