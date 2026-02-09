import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_error.dart';
import '../core/diagnostics_report_formatter.dart';
import '../services/app_error_reporter.dart';
import '../services/build_info.dart';
import '../services/diagnostics_log.dart';
import '../services/save_file.dart';
import '../ui/app_strings.dart';

class DiagnosticsScreen extends StatefulWidget {
  DiagnosticsScreen({
    super.key,
    AppErrorReporter? reporter,
    Future<String> Function(String fileName, List<int> bytes)? saveReportBytes,
    Future<void> Function(String text)? copyReportText,
    Future<void> Function(String fileName, List<int> bytes, String mimeType)?
        shareReportBytes,
    Future<DiagnosticsAppInfo> Function()? loadAppInfo,
    DateTime Function()? now,
    void Function(DiagnosticsGeneratedReport payload)? debugOnReportGenerated,
  })  : reporter = reporter ?? AppErrorReporter.I,
        saveReportBytes = saveReportBytes ?? saveBytes,
        copyReportText = copyReportText ?? _copyWithClipboard,
        shareReportBytes = shareReportBytes ?? _shareWithSystem,
        loadAppInfo = loadAppInfo ?? _loadAppInfoFromPlatform,
        now = now ?? DateTime.now,
        debugOnReportGenerated = _debugOnlyHook(debugOnReportGenerated);

  static const routeTitle = AppStrings.diagnosticsTitle;

  final AppErrorReporter reporter;
  final Future<String> Function(String fileName, List<int> bytes)
      saveReportBytes;
  final Future<void> Function(String text) copyReportText;
  final Future<void> Function(String fileName, List<int> bytes, String mimeType)
      shareReportBytes;
  final Future<DiagnosticsAppInfo> Function() loadAppInfo;
  final DateTime Function() now;
  final void Function(DiagnosticsGeneratedReport payload)?
      debugOnReportGenerated;

  static void Function(DiagnosticsGeneratedReport payload)? _debugOnlyHook(
    void Function(DiagnosticsGeneratedReport payload)? hook,
  ) {
    void Function(DiagnosticsGeneratedReport payload)? result;
    assert(() {
      result = hook;
      return true;
    }());
    return result;
  }

  static Future<void> _copyWithClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> _shareWithSystem(
    String fileName,
    List<int> bytes,
    String mimeType,
  ) async {
    final file = XFile.fromData(
      Uint8List.fromList(bytes),
      name: fileName,
      mimeType: mimeType,
    );
    await Share.shareXFiles([file], subject: fileName);
  }

  static Future<DiagnosticsAppInfo> _loadAppInfoFromPlatform() async {
    final info = await PackageInfo.fromPlatform();
    final appName = info.appName.trim().isEmpty ? 'BitFlow' : info.appName;
    return DiagnosticsAppInfo(
      appName: appName,
      packageName: info.packageName.trim(),
      version: info.version.trim(),
      buildNumber: info.buildNumber.trim(),
    );
  }

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final Set<String> _expandedEventIds = <String>{};
  String? _feedback;
  DiagnosticsAppInfo _appInfo = const DiagnosticsAppInfo(
    appName: 'BitFlow',
    packageName: 'unknown',
    version: 'unknown',
    buildNumber: '',
  );

  @override
  void initState() {
    super.initState();
    unawaited(widget.reporter.init());
    unawaited(_loadAppInfo());
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await widget.loadAppInfo();
      if (!mounted) return;
      setState(() => _appInfo = info);
    } catch (_) {
      // Keep the unknown fallback without interrupting the diagnostics screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text(DiagnosticsScreen.routeTitle),
      ),
      child: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: widget.reporter.revision,
          builder: (context, _, __) {
            final events =
                widget.reporter.recent(limit: widget.reporter.capacity);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: [
                _sectionTitle(AppStrings.diagnosticsSummary),
                _card(
                  children: [
                    _row(AppStrings.diagnosticsVersionBuild, BuildInfo.stamp),
                    _row(AppStrings.diagnosticsVersion, _appInfo.versionLabel),
                    _row(AppStrings.diagnosticsAppId, _appInfo.packageName),
                    _row(AppStrings.diagnosticsPlatform, _platformLabel()),
                    _row(AppStrings.diagnosticsLocale, _localeLabel(context)),
                    _row(
                      AppStrings.diagnosticsRuntime,
                      'release=$kReleaseMode  debug=$kDebugMode  profile=$kProfileMode',
                    ),
                    _row(
                      AppStrings.diagnosticsTextScale,
                      textScale.toStringAsFixed(2),
                    ),
                    _row(
                      AppStrings.diagnosticsErrorStorage,
                      widget.reporter.isUsingMemoryFallback
                          ? AppStrings.diagnosticsStorageMemoryFallback
                          : AppStrings.diagnosticsStorageLocal,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionTitle(AppStrings.diagnosticsReport),
                _card(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            onPressed: () => _copyReport(events),
                            child: const Text(AppStrings.diagnosticsCopyReport),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CupertinoButton(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            onPressed: () => _exportReport(events),
                            child:
                                const Text(AppStrings.diagnosticsExportReport),
                          ),
                        ),
                      ],
                    ),
                    if ((_feedback ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _feedback!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _sectionTitle(AppStrings.diagnosticsRecentErrors),
                if (events.isEmpty)
                  _card(
                    children: const [
                      Text(
                        AppStrings.diagnosticsNoRecentErrors,
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  )
                else
                  ...events.map(_eventCard),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _eventCard(AppErrorEvent event) {
    final expanded = _expandedEventIds.contains(event.id);
    final detail = event.technicalDetail.trim();
    final canExpand = detail.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _card(
        children: [
          Text(
            event.userMessage,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _row(
            AppStrings.diagnosticsFlowLabel,
            '${event.flow.name} / ${event.kind.name}',
          ),
          _row(AppStrings.diagnosticsDateLabel,
              DiagnosticsReportFormatter.formatDateTime(event.at)),
          if (canExpand) ...[
            const SizedBox(height: 2),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  if (expanded) {
                    _expandedEventIds.remove(event.id);
                  } else {
                    _expandedEventIds.add(event.id);
                  }
                });
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  expanded
                      ? AppStrings.diagnosticsDetailsHide
                      : AppStrings.diagnosticsDetailsShow,
                ),
              ),
            ),
            if (expanded)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  detail,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _copyReport(List<AppErrorEvent> events) async {
    final now = widget.now();
    final metadata = _buildMetadata(now);
    final reasonCounts = DiagnosticsLog.I.attachmentReasonCounters.value;
    final text = DiagnosticsReportFormatter.buildText(
      metadata: metadata,
      events: events,
      attachmentReasonCounts: reasonCounts,
    );
    try {
      await widget.copyReportText(text);
      _setFeedback(AppStrings.diagnosticsReportCopied);
    } catch (error, stackTrace) {
      _recordDiagnosticsFailure(
        error,
        operation: 'diagnostics_copy_report',
        fallbackMessage: AppStrings.diagnosticsReportCopyFailed,
        stackTrace: stackTrace,
      );
      _setFeedback(AppStrings.diagnosticsReportCopyFailed);
    }
  }

  Future<void> _exportReport(List<AppErrorEvent> events) async {
    if (!mounted) return;

    final format = await showCupertinoModalPopup<_ReportFormat>(
      context: context,
      builder: (ctx) {
        return CupertinoActionSheet(
          title: const Text(AppStrings.diagnosticsExportSheetTitle),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(_ReportFormat.txt),
              child: const Text(AppStrings.diagnosticsExportTxtOption),
            ),
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(_ReportFormat.json),
              child: const Text(AppStrings.diagnosticsExportJsonOption),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(ctx).pop(),
            isDefaultAction: true,
            child: const Text(AppStrings.cancel),
          ),
        );
      },
    );

    if (format == null) return;

    final generated = widget.now();
    final metadata = _buildMetadata(generated);
    final payload = _buildExportPayload(
      metadata: metadata,
      events: events,
      format: format,
    );

    await _shareOrSaveReport(payload);
  }

  Future<void> _shareOrSaveReport(_DiagnosticsReportPayload payload) async {
    if (_preferSharePath()) {
      try {
        await widget.shareReportBytes(
          payload.fileName,
          payload.bytes,
          payload.mimeType,
        );
        _setFeedback(AppStrings.diagnosticsShareSaved);
        return;
      } catch (error, stackTrace) {
        _recordDiagnosticsFailure(
          error,
          operation: 'diagnostics_share_report',
          fallbackMessage: AppStrings.diagnosticsShareUnavailableCopied,
          stackTrace: stackTrace,
        );
        await _fallbackCopyOnly(
          payload,
          messageOnSuccess: AppStrings.diagnosticsShareUnavailableCopied,
          operationOnFailure: 'diagnostics_share_copy_fallback',
        );
        return;
      }
    }

    try {
      final location =
          await widget.saveReportBytes(payload.fileName, payload.bytes);
      _setFeedback('${AppStrings.diagnosticsReportExportedPrefix}$location');
    } catch (error, stackTrace) {
      _recordDiagnosticsFailure(
        error,
        operation: 'diagnostics_save_report',
        fallbackMessage: AppStrings.diagnosticsSaveUnavailableCopied,
        stackTrace: stackTrace,
      );
      await _fallbackCopyOnly(
        payload,
        messageOnSuccess: AppStrings.diagnosticsSaveUnavailableCopied,
        operationOnFailure: 'diagnostics_save_copy_fallback',
      );
    }
  }

  Future<void> _fallbackCopyOnly(
    _DiagnosticsReportPayload payload, {
    required String messageOnSuccess,
    required String operationOnFailure,
  }) async {
    try {
      await widget.copyReportText(payload.textReport);
      _setFeedback(messageOnSuccess);
    } catch (error, stackTrace) {
      _recordDiagnosticsFailure(
        error,
        operation: operationOnFailure,
        fallbackMessage: AppStrings.diagnosticsReportCopyFailed,
        stackTrace: stackTrace,
      );
      _setFeedback(AppStrings.diagnosticsReportCopyFailed);
    }
  }

  void _recordDiagnosticsFailure(
    Object error, {
    required String operation,
    required String fallbackMessage,
    StackTrace? stackTrace,
  }) {
    final appError = AppErrorMapper.from(
      error,
      flow: AppErrorFlow.exportData,
      fallbackMessage: fallbackMessage,
    );
    widget.reporter.record(
      appError,
      operation: operation,
      stackTrace: stackTrace,
    );
  }

  DiagnosticsReportMetadata _buildMetadata(DateTime generatedAt) {
    return DiagnosticsReportMetadata(
      generatedAt: generatedAt,
      buildStamp: BuildInfo.stamp,
      buildInfo: BuildInfo.toJson(),
      appInfo: _appInfo,
      platform: _platformLabel(),
      locale: _localeLabel(context),
      runtimeRelease: kReleaseMode,
      runtimeDebug: kDebugMode,
      runtimeProfile: kProfileMode,
      textScale: MediaQuery.textScalerOf(context).scale(1),
      errorStorage: widget.reporter.isUsingMemoryFallback
          ? AppStrings.diagnosticsStorageMemoryFallback
          : AppStrings.diagnosticsStorageLocal,
    );
  }

  _DiagnosticsReportPayload _buildExportPayload({
    required DiagnosticsReportMetadata metadata,
    required List<AppErrorEvent> events,
    required _ReportFormat format,
  }) {
    final reasonCounts = DiagnosticsLog.I.attachmentReasonCounters.value;
    final traces = DiagnosticsLog.I
        .recentAttachmentTraces(limit: 80)
        .map((trace) => <String, dynamic>{
              'operation_id': trace.operationId,
              'cell_id': trace.cellId,
              'attachment_type': trace.attachmentType,
              'source': trace.source,
              'step': trace.step.name,
              'ok': trace.ok,
              'elapsed_ms': trace.elapsedMs,
              'at': trace.at.toIso8601String(),
              if ((trace.reason ?? '').trim().isNotEmpty)
                'reason': trace.reason,
              if ((trace.techDetail ?? '').trim().isNotEmpty)
                'tech_detail': trace.techDetail,
            })
        .toList(growable: false);
    final text = DiagnosticsReportFormatter.buildText(
      metadata: metadata,
      events: events,
      attachmentReasonCounts: reasonCounts,
    );
    final jsonMap = DiagnosticsReportFormatter.buildJson(
      metadata: metadata,
      events: events,
      attachmentReasonCounts: reasonCounts,
      attachmentTraces: traces,
    );

    final extension = format == _ReportFormat.txt ? 'txt' : 'json';
    final fileName =
        'bitflow_soporte_${DiagnosticsReportFormatter.fileStamp(metadata.generatedAt)}.$extension';

    if (format == _ReportFormat.txt) {
      final payload = _DiagnosticsReportPayload(
        fileName: fileName,
        mimeType: 'text/plain',
        bytes: utf8.encode(text),
        textReport: text,
      );
      _recordDebugGeneratedReport(
        format: format,
        fileName: fileName,
        mimeType: payload.mimeType,
        textReport: text,
        jsonReport: jsonMap,
      );
      return payload;
    }

    final payload = _DiagnosticsReportPayload(
      fileName: fileName,
      mimeType: 'application/json',
      bytes: utf8.encode(jsonEncode(jsonMap)),
      textReport: text,
    );
    _recordDebugGeneratedReport(
      format: format,
      fileName: fileName,
      mimeType: payload.mimeType,
      textReport: text,
      jsonReport: jsonMap,
    );
    return payload;
  }

  void _recordDebugGeneratedReport({
    required _ReportFormat format,
    required String fileName,
    required String mimeType,
    required String textReport,
    required Map<String, dynamic> jsonReport,
  }) {
    assert(() {
      final report = DiagnosticsGeneratedReport(
        format: format == _ReportFormat.json
            ? DiagnosticsGeneratedReportFormat.json
            : DiagnosticsGeneratedReportFormat.text,
        fileName: fileName,
        mimeType: mimeType,
        textReport: textReport,
        jsonReport: Map<String, dynamic>.from(jsonReport),
      );
      DiagnosticsDebugHooks._recordReport(report);
      widget.debugOnReportGenerated?.call(report);
      return true;
    }());
  }

  bool _preferSharePath() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _setFeedback(String message) {
    if (!mounted) return;
    setState(() => _feedback = message);
  }

  String _localeLabel(BuildContext context) {
    final locale = Localizations.maybeLocaleOf(context);
    return locale?.toLanguageTag() ?? 'unknown';
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CupertinoColors.systemGrey4),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 136,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: CupertinoColors.systemGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

enum DiagnosticsGeneratedReportFormat { json, text }

class DiagnosticsGeneratedReport {
  const DiagnosticsGeneratedReport({
    required this.format,
    required this.fileName,
    required this.mimeType,
    required this.textReport,
    required this.jsonReport,
  });

  final DiagnosticsGeneratedReportFormat format;
  final String fileName;
  final String mimeType;
  final String textReport;
  final Map<String, dynamic> jsonReport;
}

class DiagnosticsDebugHooks {
  DiagnosticsDebugHooks._();

  static DiagnosticsGeneratedReport? _lastGeneratedReport;

  static DiagnosticsGeneratedReport? get lastGeneratedReport {
    DiagnosticsGeneratedReport? value;
    assert(() {
      value = _lastGeneratedReport;
      return true;
    }());
    return value;
  }

  static void clearLastGeneratedReport() {
    assert(() {
      _lastGeneratedReport = null;
      return true;
    }());
  }

  static void _recordReport(DiagnosticsGeneratedReport report) {
    assert(() {
      _lastGeneratedReport = report;
      return true;
    }());
  }
}

class _DiagnosticsReportPayload {
  const _DiagnosticsReportPayload({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.textReport,
  });

  final String fileName;
  final String mimeType;
  final List<int> bytes;
  final String textReport;
}

enum _ReportFormat { txt, json }
