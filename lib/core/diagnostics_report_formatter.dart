import 'dart:convert';

import '../services/app_error_reporter.dart';

class DiagnosticsAppInfo {
  const DiagnosticsAppInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  String get versionLabel {
    final v = version.trim();
    final b = buildNumber.trim();
    if (v.isEmpty && b.isEmpty) return 'unknown';
    if (b.isEmpty) return v;
    if (v.isEmpty) return b;
    return '$v ($b)';
  }
}

class DiagnosticsReportMetadata {
  const DiagnosticsReportMetadata({
    required this.generatedAt,
    required this.buildStamp,
    required this.buildInfo,
    required this.appInfo,
    required this.platform,
    required this.locale,
    required this.runtimeRelease,
    required this.runtimeDebug,
    required this.runtimeProfile,
    required this.textScale,
    required this.errorStorage,
  });

  final DateTime generatedAt;
  final String buildStamp;
  final Map<String, dynamic> buildInfo;
  final DiagnosticsAppInfo appInfo;
  final String platform;
  final String locale;
  final bool runtimeRelease;
  final bool runtimeDebug;
  final bool runtimeProfile;
  final double textScale;
  final String errorStorage;
}

class DiagnosticsReportFormatter {
  const DiagnosticsReportFormatter._();
  static const int schemaVersion = 1;
  static const int maxEvents = 50;
  static const int maxTechnicalDetailChars = 3072;

  static Map<String, dynamic> buildJson({
    required DiagnosticsReportMetadata metadata,
    required Iterable<AppErrorEvent> events,
    Map<String, int> attachmentReasonCounts = const <String, int>{},
    Iterable<Map<String, dynamic>> attachmentTraces =
        const <Map<String, dynamic>>[],
  }) {
    final bounded = _boundedEvents(events);
    final orderedReasonCounts = Map<String, int>.fromEntries(
      attachmentReasonCounts.entries.toList(growable: false)
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    final traceList = attachmentTraces.toList(growable: false);
    return <String, dynamic>{
      'schema_version': schemaVersion,
      'generated_at_utc': metadata.generatedAt.toUtc().toIso8601String(),
      'generatedAt': metadata.generatedAt.toIso8601String(),
      'app': <String, dynamic>{
        'name': metadata.appInfo.appName,
        'packageName': metadata.appInfo.packageName,
        'version': metadata.appInfo.version,
        'buildNumber': metadata.appInfo.buildNumber,
        'versionLabel': metadata.appInfo.versionLabel,
        'buildStamp': metadata.buildStamp,
      },
      'device': <String, dynamic>{
        'platform': metadata.platform,
        'locale': metadata.locale,
        'textScale': metadata.textScale,
      },
      'runtime': <String, dynamic>{
        'release': metadata.runtimeRelease,
        'debug': metadata.runtimeDebug,
        'profile': metadata.runtimeProfile,
      },
      'errorStorage': metadata.errorStorage,
      'build': _stableBuildInfo(metadata.buildInfo),
      'attachmentReasonCounts': orderedReasonCounts,
      'attachmentTraces': traceList,
      'truncated': bounded.truncated,
      'events': bounded.events
          .map((event) => _eventToJson(event))
          .toList(growable: false),
    };
  }

  static String buildText({
    required DiagnosticsReportMetadata metadata,
    required Iterable<AppErrorEvent> events,
    Map<String, int> attachmentReasonCounts = const <String, int>{},
  }) {
    final bounded = _boundedEvents(events);
    final orderedEvents = bounded.events;
    final sortedReasons = attachmentReasonCounts.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    final buffer = StringBuffer()
      ..writeln('BitFlow - Diagnóstico / Soporte')
      ..writeln('Generado: ${metadata.generatedAt.toIso8601String()}')
      ..writeln('Version/Build: ${metadata.buildStamp}')
      ..writeln('Version: ${metadata.appInfo.versionLabel}')
      ..writeln('App ID: ${metadata.appInfo.packageName}')
      ..writeln('Plataforma: ${metadata.platform}')
      ..writeln('Locale: ${metadata.locale}')
      ..writeln(
        'Runtime: release=${metadata.runtimeRelease} '
        'debug=${metadata.runtimeDebug} profile=${metadata.runtimeProfile}',
      )
      ..writeln('Text scale: ${metadata.textScale.toStringAsFixed(2)}')
      ..writeln('Persistencia errores: ${metadata.errorStorage}')
      ..writeln('Errores: ${orderedEvents.length}')
      ..writeln('');

    if (sortedReasons.isNotEmpty) {
      buffer.writeln('Attachment reasons:');
      for (final entry in sortedReasons) {
        buffer.writeln('  ${entry.key}=${entry.value}');
      }
      buffer.writeln('');
    }

    if (orderedEvents.isEmpty) {
      buffer.writeln('- Sin errores recientes');
      return buffer.toString();
    }

    for (final event in orderedEvents) {
      buffer.writeln('- ${formatDateTime(event.at)}');
      buffer.writeln('  flow=${event.flow.name} kind=${event.kind.name}');
      buffer.writeln('  message=${event.userMessage}');
      final operation = event.operation?.trim() ?? '';
      if (operation.isNotEmpty) {
        buffer.writeln('  operation=$operation');
      }
      final code = event.code?.trim() ?? '';
      if (code.isNotEmpty) {
        buffer.writeln('  code=$code');
      }
      final detail = _safeTechnicalDetail(event.technicalDetail);
      if (detail.value.isNotEmpty) {
        buffer.writeln('  technicalDetail=${detail.value}');
      }
      buffer.writeln('');
    }

    return buffer.toString();
  }

  static String fileStamp(DateTime value) {
    final local = value.toLocal();
    final yy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$yy$mm${dd}_$hh$min$ss';
  }

  static String formatDateTime(DateTime value) {
    final local = value.toLocal();
    final yy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$yy-$mm-$dd $hh:$min:$ss';
  }

  static List<AppErrorEvent> _orderedEvents(Iterable<AppErrorEvent> events) {
    final list = events.toList(growable: false);
    list.sort((a, b) {
      final byDate = b.at.compareTo(a.at);
      if (byDate != 0) return byDate;
      return b.id.compareTo(a.id);
    });
    return list;
  }

  static Map<String, dynamic> _stableBuildInfo(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'gitSha': (raw['gitSha'] ?? '').toString(),
      'buildTime': (raw['buildTime'] ?? '').toString(),
      'engineBaseUrl': (raw['engineBaseUrl'] ?? '').toString(),
    };
  }

  static Map<String, dynamic> _eventToJson(AppErrorEvent event) {
    final out = <String, dynamic>{
      'id': event.id,
      'at': event.at.toIso8601String(),
      'flow': event.flow.name,
      'kind': event.kind.name,
      'userMessage': event.userMessage,
    };
    final operation = (event.operation ?? '').trim();
    if (operation.isNotEmpty) {
      out['operation'] = operation;
    }
    final code = (event.code ?? '').trim();
    if (code.isNotEmpty) {
      out['code'] = code;
    }
    final detail = _safeTechnicalDetail(event.technicalDetail);
    if (detail.value.isNotEmpty) {
      out['technicalDetail'] = detail.value;
      if (detail.truncated) {
        out['technicalDetailTruncated'] = true;
      }
    }
    return out;
  }

  static _BoundedEvents _boundedEvents(Iterable<AppErrorEvent> events) {
    final ordered = _orderedEvents(events);
    if (ordered.length <= maxEvents) {
      return _BoundedEvents(events: ordered, truncated: false);
    }
    return _BoundedEvents(
      events: ordered.take(maxEvents).toList(growable: false),
      truncated: true,
    );
  }

  static _TruncatedDetail _safeTechnicalDetail(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return const _TruncatedDetail(value: '', truncated: false);
    }
    if (value.length <= maxTechnicalDetailChars) {
      return _TruncatedDetail(value: value, truncated: false);
    }
    return _TruncatedDetail(
      value: value.substring(0, maxTechnicalDetailChars),
      truncated: true,
    );
  }

  static String toJsonString({
    required DiagnosticsReportMetadata metadata,
    required Iterable<AppErrorEvent> events,
    Map<String, int> attachmentReasonCounts = const <String, int>{},
    Iterable<Map<String, dynamic>> attachmentTraces =
        const <Map<String, dynamic>>[],
  }) {
    return jsonEncode(
      buildJson(
        metadata: metadata,
        events: events,
        attachmentReasonCounts: attachmentReasonCounts,
        attachmentTraces: attachmentTraces,
      ),
    );
  }
}

class _BoundedEvents {
  const _BoundedEvents({required this.events, required this.truncated});

  final List<AppErrorEvent> events;
  final bool truncated;
}

class _TruncatedDetail {
  const _TruncatedDetail({required this.value, required this.truncated});

  final String value;
  final bool truncated;
}
