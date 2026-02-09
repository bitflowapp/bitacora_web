import 'dart:convert';

import 'package:bitacora_web/core/app_error.dart';
import 'package:bitacora_web/core/diagnostics_report_formatter.dart';
import 'package:bitacora_web/services/app_error_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostics formatter creates deterministic schema and stable ordering',
      () {
    final metadata = DiagnosticsReportMetadata(
      generatedAt: DateTime.utc(2026, 2, 7, 12, 30, 0),
      buildStamp: 'Build: abc1234',
      buildInfo: const <String, dynamic>{
        'gitSha': 'abc1234',
        'buildTime': '2026-02-07T12:20:00Z',
        'engineBaseUrl': 'https://engine.example',
      },
      appInfo: const DiagnosticsAppInfo(
        appName: 'BitFlow',
        packageName: 'com.bitflow.app',
        version: '1.2.3',
        buildNumber: '45',
      ),
      platform: 'android',
      locale: 'es-AR',
      runtimeRelease: true,
      runtimeDebug: false,
      runtimeProfile: false,
      textScale: 1.25,
      errorStorage: 'local',
    );

    final events = <AppErrorEvent>[
      AppErrorEvent(
        id: 'evt_old',
        at: DateTime.utc(2026, 2, 7, 11, 0, 0),
        flow: AppErrorFlow.save,
        kind: AppErrorKind.storage,
        userMessage: 'No se pudo guardar.',
        technicalDetail: 'op=save_local',
        operation: 'save_local',
        code: 'save_error',
      ),
      AppErrorEvent(
        id: 'evt_new',
        at: DateTime.utc(2026, 2, 7, 12, 0, 0),
        flow: AppErrorFlow.exportData,
        kind: AppErrorKind.unavailable,
        userMessage: 'No se pudo exportar.',
        technicalDetail: 'op=diagnostics_share_report',
        operation: 'diagnostics_share_report',
      ),
    ];

    final json = DiagnosticsReportFormatter.buildJson(
      metadata: metadata,
      events: events,
      attachmentReasonCounts: const <String, int>{
        'storage_blocked': 2,
        'unsupported_format': 1,
      },
      attachmentTraces: const <Map<String, dynamic>>[
        <String, dynamic>{
          'operation_id': 'photo_123',
          'step': 'persist',
          'ok': false,
        },
      ],
    );

    expect(
      json.keys.toList(growable: false),
      <String>[
        'schema_version',
        'generated_at_utc',
        'generatedAt',
        'app',
        'device',
        'runtime',
        'errorStorage',
        'build',
        'attachmentReasonCounts',
        'attachmentTraces',
        'truncated',
        'events',
      ],
    );
    expect(json['schema_version'], DiagnosticsReportFormatter.schemaVersion);
    expect(
      json['generated_at_utc'],
      DateTime.utc(2026, 2, 7, 12, 30, 0).toIso8601String(),
    );
    expect(json['truncated'], isFalse);
    expect(
      json['attachmentReasonCounts'],
      const <String, int>{
        'storage_blocked': 2,
        'unsupported_format': 1,
      },
    );
    expect((json['attachmentTraces'] as List).length, 1);

    final app = json['app'] as Map<String, dynamic>;
    expect(app['versionLabel'], '1.2.3 (45)');

    final encoded = jsonEncode(json);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    final decodedEvents =
        (decoded['events'] as List<dynamic>).cast<Map<String, dynamic>>();

    expect(decodedEvents.first['id'], 'evt_new');
    expect(decodedEvents.last['id'], 'evt_old');

    expect(
      decodedEvents.first.keys.toList(growable: false),
      <String>[
        'id',
        'at',
        'flow',
        'kind',
        'userMessage',
        'operation',
        'technicalDetail',
      ],
    );

    final text = DiagnosticsReportFormatter.buildText(
      metadata: metadata,
      events: events,
      attachmentReasonCounts: const <String, int>{'storage_blocked': 2},
    );
    expect(text, contains('Version: 1.2.3 (45)'));
    expect(text, contains('Plataforma: android'));
    expect(text, contains('flow=exportData kind=unavailable'));
    expect(text, contains('Attachment reasons:'));
  });

  test('caps events and truncates long technical detail safely', () {
    final metadata = DiagnosticsReportMetadata(
      generatedAt: DateTime.utc(2026, 2, 7, 12, 30, 0),
      buildStamp: 'Build: abc1234',
      buildInfo: const <String, dynamic>{},
      appInfo: const DiagnosticsAppInfo(
        appName: 'BitFlow',
        packageName: 'com.bitflow.app',
        version: '1.0.0',
        buildNumber: '1',
      ),
      platform: 'web',
      locale: 'en-US',
      runtimeRelease: false,
      runtimeDebug: true,
      runtimeProfile: false,
      textScale: 1,
      errorStorage: 'memory',
    );
    final veryLongDetail = List.filled(
            DiagnosticsReportFormatter.maxTechnicalDetailChars + 512, 'x')
        .join();

    final events = List<AppErrorEvent>.generate(
      DiagnosticsReportFormatter.maxEvents + 5,
      (index) => AppErrorEvent(
        id: 'evt_$index',
        at: DateTime.utc(2026, 2, 7, 12, 0, index),
        flow: AppErrorFlow.exportData,
        kind: AppErrorKind.unknown,
        userMessage: 'msg_$index',
        technicalDetail: veryLongDetail,
      ),
    );

    final json = DiagnosticsReportFormatter.buildJson(
      metadata: metadata,
      events: events,
      attachmentReasonCounts: const <String, int>{'quota': 3},
    );
    final encoded = jsonEncode(json);
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    final decodedEvents =
        (decoded['events'] as List<dynamic>).cast<Map<String, dynamic>>();

    expect(decoded['truncated'], isTrue);
    expect(decodedEvents.length, DiagnosticsReportFormatter.maxEvents);
    expect(decodedEvents.first['technicalDetailTruncated'], isTrue);
    final detail = decodedEvents.first['technicalDetail'] as String;
    expect(detail.length, lessThanOrEqualTo(3100));

    final text = DiagnosticsReportFormatter.buildText(
      metadata: metadata,
      events: events,
    );
    expect(text, contains('technicalDetail='));
  });
}
