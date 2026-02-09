import 'package:bitacora_web/core/app_error.dart';
import 'package:bitacora_web/core/diagnostics_report_formatter.dart';
import 'package:bitacora_web/screens/diagnostics_screen.dart';
import 'package:bitacora_web/services/app_error_reporter.dart';
import 'package:bitacora_web/ui/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixedNow = DateTime.utc(2026, 2, 8, 14, 30, 0);

  setUp(() {
    DiagnosticsDebugHooks.clearLastGeneratedReport();
  });

  testWidgets('builds diagnostics screen with empty recent errors state',
      (tester) async {
    final reporter = AppErrorReporter(
      storage: MemoryAppErrorReporterStorage(),
      capacity: 50,
    );
    await reporter.init();

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticsScreen(
          reporter: reporter,
          loadAppInfo: _testAppInfo,
          copyReportText: (_) async {},
          saveReportBytes: (_, __) async => 'ok',
          shareReportBytes: (_, __, ___) async {},
          now: () => fixedNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(DiagnosticsScreen.routeTitle), findsOneWidget);
    expect(find.text(AppStrings.diagnosticsNoRecentErrors), findsOneWidget);
    expect(find.text(AppStrings.diagnosticsExportReport), findsOneWidget);
  });

  testWidgets(
      'tapping Exportar informe (JSON) generates payload via debug hook',
      (tester) async {
    final reporter = AppErrorReporter(
      storage: MemoryAppErrorReporterStorage(),
      capacity: 50,
    );
    await reporter.init();
    reporter.record(
      const AppError(
        flow: AppErrorFlow.exportData,
        kind: AppErrorKind.storage,
        userMessage: 'Error de prueba',
        technicalMessage: r'C:\tmp\secret_token=abc',
      ),
      operation: 'widget_test',
    );
    await reporter.flush();

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticsScreen(
          reporter: reporter,
          loadAppInfo: _testAppInfo,
          copyReportText: (_) async {},
          saveReportBytes: (_, __) async => 'saved',
          shareReportBytes: (_, __, ___) async {},
          now: () => fixedNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Error de prueba'), findsOneWidget);

    await tester.tap(find.text(AppStrings.diagnosticsExportReport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.diagnosticsExportJsonOption));
    await tester.pumpAndSettle();

    final generated = DiagnosticsDebugHooks.lastGeneratedReport;
    expect(generated, isNotNull);
    expect(generated!.format, DiagnosticsGeneratedReportFormat.json);
    expect(generated.fileName, startsWith('bitflow_soporte_'));
    expect(generated.fileName, endsWith('.json'));
    expect(generated.mimeType, 'application/json');
    expect(generated.jsonReport['schema_version'], 1);
    expect(
        generated.jsonReport['generated_at_utc'], fixedNow.toIso8601String());
    final events = generated.jsonReport['events'] as List<dynamic>;
    expect(events, isNotEmpty);
    expect(events.first.toString(), contains('Error de prueba'));
    expect(generated.textReport, contains('Version:'));
    expect(generated.textReport, contains('Plataforma:'));
    expect(generated.textReport, contains('Locale:'));
    expect(generated.textReport, contains('Errores:'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing Texto plano captures plain-text payload',
      (tester) async {
    final reporter = AppErrorReporter(
      storage: MemoryAppErrorReporterStorage(),
      capacity: 50,
    );
    await reporter.init();
    reporter.record(
      const AppError(
        flow: AppErrorFlow.exportData,
        kind: AppErrorKind.unknown,
        userMessage: 'Error texto',
        technicalMessage: 'technical detail',
      ),
      operation: 'txt_export_test',
    );
    await reporter.flush();

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticsScreen(
          reporter: reporter,
          loadAppInfo: _testAppInfo,
          copyReportText: (_) async {},
          saveReportBytes: (_, __) async => 'saved',
          shareReportBytes: (_, __, ___) async {},
          now: () => fixedNow,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.diagnosticsExportReport));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.diagnosticsExportTxtOption));
    await tester.pumpAndSettle();

    final generated = DiagnosticsDebugHooks.lastGeneratedReport;
    expect(generated, isNotNull);
    expect(generated!.format, DiagnosticsGeneratedReportFormat.text);
    expect(generated.fileName, endsWith('.txt'));
    expect(generated.mimeType, 'text/plain');
    expect(generated.textReport, contains('Version:'));
    expect(generated.textReport, contains('Plataforma:'));
    expect(generated.textReport, contains('Locale:'));
    expect(generated.textReport, contains('Errores:'));
    expect(generated.textReport, contains('flow=exportData kind=unknown'));
    expect(tester.takeException(), isNull);
  });
}

Future<DiagnosticsAppInfo> _testAppInfo() async {
  return const DiagnosticsAppInfo(
    appName: 'BitFlow',
    packageName: 'com.bitflow.test',
    version: '1.2.3',
    buildNumber: '45',
  );
}
