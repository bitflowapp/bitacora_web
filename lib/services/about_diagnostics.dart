import 'dart:convert';

class AboutDiagnosticsPayload {
  const AboutDiagnosticsPayload({
    required this.version,
    required this.build,
    required this.platform,
    required this.isWeb,
    required this.reducedMotion,
    required this.timestamp,
    this.sheetName,
    this.rows,
    this.cols,
  });

  final String version;
  final String build;
  final String platform;
  final bool isWeb;
  final bool reducedMotion;
  final DateTime timestamp;
  final String? sheetName;
  final int? rows;
  final int? cols;
}

String buildAboutDiagnosticsText(AboutDiagnosticsPayload payload) {
  final sheetLabel = (payload.sheetName ?? '').trim().isEmpty
      ? 'n/a'
      : payload.sheetName!.trim();
  final rowsLabel = payload.rows?.toString() ?? 'n/a';
  final colsLabel = payload.cols?.toString() ?? 'n/a';
  return [
    'BitFlow Diagnostics',
    'version=${payload.version.trim().isEmpty ? 'unknown' : payload.version.trim()}',
    'build=${payload.build.trim().isEmpty ? 'unknown' : payload.build.trim()}',
    'platform=${payload.platform}',
    'runtime=${payload.isWeb ? 'web' : 'mobile'}',
    'reduced_motion=${payload.reducedMotion}',
    'timestamp=${payload.timestamp.toUtc().toIso8601String()}',
    'sheet_name=$sheetLabel',
    'rows=$rowsLabel',
    'cols=$colsLabel',
  ].join('\n');
}

({String? name, int? rows, int? cols}) parseSheetSnapshotFromRaw(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return (name: null, rows: null, cols: null);
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return (name: null, rows: null, cols: null);
    }
    final name = (decoded['name'] ?? '').toString().trim();
    final headers =
        decoded['headers'] is List ? decoded['headers'] as List : const [];
    final rows = decoded['rows'] is List ? decoded['rows'] as List : const [];
    return (
      name: name.isEmpty ? null : name,
      rows: rows.length,
      cols: headers.length,
    );
  } catch (_) {
    return (name: null, rows: null, cols: null);
  }
}
