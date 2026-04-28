import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'engine_config.dart';
import 'save_bytes.dart';

/// Client for BitFlow / Cathodic / XLSX Engine (FastAPI).
/// - Web: uses HTTPS tunnel by default (avoid CORS/ATS issues).
/// - Non-web: tries LAN, falls back to tunnel.
/// - No dart:io (web compatible).
class EngineApi {
  EngineApi({
    http.Client? client,
    EngineConfig? config,
    String? lanBase,
    String? tunnelBase,
    this.connectProbePath = '/openapi.json',
  })  : _client = client ?? http.Client(),
        _config = config ?? EngineConfig.instance,
        lanBase = lanBase ?? EngineConfig.defaultLanBaseUrl,
        tunnelBase = tunnelBase ?? EngineConfig.defaultTunnelBaseUrl;

  final http.Client _client;
  final EngineConfig _config;

  /// Base LAN for the engine on the local network.
  final String lanBase;

  /// HTTPS base via Cloudflare Tunnel.
  final String tunnelBase;

  /// Lightweight endpoint for connectivity checks.
  final String connectProbePath;

  Uri? _resolvedBase;
  Completer<Uri>? _resolving;

  /// Resolves and caches the base URL to use.
  /// - Web: tunnel (unless manual/query override).
  /// - Non-web: LAN with short timeout, else tunnel.
  Future<Uri> resolveBaseUri() async {
    final cached = _resolvedBase;
    if (cached != null) return cached;

    final inflight = _resolving;
    if (inflight != null) return inflight.future;

    final completer = Completer<Uri>();
    _resolving = completer;

    try {
      final preferred = await _config.resolvePreferredBaseUrl();
      if (preferred != null && preferred.trim().isNotEmpty) {
        final u = Uri.parse(_normalizeBase(preferred));
        _resolvedBase = u;
        await _config.setLastResolved(u.toString());
        completer.complete(u);
        return u;
      }

      if (kIsWeb) {
        final fromVersion = await _tryLoadBaseFromVersionJson();
        if (fromVersion != null && fromVersion.trim().isNotEmpty) {
          final u = Uri.parse(_normalizeBase(fromVersion));
          _resolvedBase = u;
          await _config.setLastResolved(u.toString());
          completer.complete(u);
          return u;
        }
        final u = Uri.parse(_normalizeBase(tunnelBase));
        _resolvedBase = u;
        await _config.setLastResolved(u.toString());
        completer.complete(u);
        return u;
      }

      final lan = Uri.parse(_normalizeBase(lanBase));
      final tunnel = Uri.parse(_normalizeBase(tunnelBase));

      final okLan = await _probe(lan);
      final chosen = okLan ? lan : tunnel;

      _resolvedBase = chosen;
      await _config.setLastResolved(chosen.toString());
      completer.complete(chosen);
      return chosen;
    } catch (e, st) {
      final fallback = Uri.parse(_normalizeBase(tunnelBase));
      _resolvedBase = fallback;
      if (!completer.isCompleted) completer.complete(fallback);
      if (kDebugMode) {
        debugPrint('EngineApi.resolveBaseUri fallback: $e\n$st');
      }
      return fallback;
    } finally {
      _resolving = null;
    }
  }

  Future<String?> _tryLoadBaseFromVersionJson() async {
    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
      final versionUri = Uri.base.resolve('version.json?x=$cacheBuster');
      final resp = await _client.get(versionUri, headers: const {
        'Cache-Control': 'no-store'
      }).timeout(const Duration(seconds: 6));

      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) return null;

      final raw = decoded['engine_url'] ??
          decoded['engine_base_url'] ??
          decoded['engine'];
      if (raw is! String) return null;

      final trimmed = raw.trim();
      if (trimmed.isEmpty || !EngineConfig.isValidBaseUrl(trimmed)) {
        return null;
      }
      return EngineConfig.normalize(trimmed);
    } catch (_) {
      return null;
    }
  }

  /// JSON -> JSON call with timeout and clear errors.
  Future<Map<String, dynamic>> postJson(
    String path, {
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 12),
    Map<String, String>? headers,
  }) async {
    final uri = await _buildUri(path);

    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      ...?headers,
    };

    final resp = await _client
        .post(uri, headers: h, body: jsonEncode(_stripNulls(body)))
        .timeout(timeout);

    final text = _decodeBody(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EngineApiException(
        statusCode: resp.statusCode,
        url: uri.toString(),
        bodySnippet: _snippet(text),
      );
    }

    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;

    throw EngineApiException(
      statusCode: resp.statusCode,
      url: uri.toString(),
      bodySnippet: 'Response is not a JSON object: ${_snippet(text)}',
    );
  }

  /// JSON GET with timeout and clear errors.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Duration timeout = const Duration(seconds: 8),
    Map<String, String>? headers,
    bool cacheBust = false,
  }) async {
    final uri = await _buildUri(path, cacheBust: cacheBust);

    final h = <String, String>{
      'Accept': 'application/json',
      ...?headers,
    };

    final resp = await _client.get(uri, headers: h).timeout(timeout);
    final text = _decodeBody(resp);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EngineApiException(
        statusCode: resp.statusCode,
        url: uri.toString(),
        bodySnippet: _snippet(text),
      );
    }

    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;

    throw EngineApiException(
      statusCode: resp.statusCode,
      url: uri.toString(),
      bodySnippet: 'Response is not a JSON object: ${_snippet(text)}',
    );
  }

  /// JSON GET for a specific base URL (used by settings probe).
  Future<Map<String, dynamic>> getJsonFromBase(
    String baseUrl,
    String path, {
    Duration timeout = const Duration(seconds: 8),
    Map<String, String>? headers,
  }) async {
    final normalized = EngineConfig.normalize(baseUrl);
    if (!EngineConfig.isValidBaseUrl(normalized)) {
      throw const EngineApiDataException('Invalid base URL.');
    }

    final base = Uri.parse(normalized);
    final uri = base.replace(path: _joinPath(base.path, path));

    final h = <String, String>{
      'Accept': 'application/json',
      ...?headers,
    };

    final resp = await _client.get(uri, headers: h).timeout(timeout);
    final text = _decodeBody(resp);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EngineApiException(
        statusCode: resp.statusCode,
        url: uri.toString(),
        bodySnippet: _snippet(text),
      );
    }

    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;

    throw EngineApiException(
      statusCode: resp.statusCode,
      url: uri.toString(),
      bodySnippet: 'Response is not a JSON object: ${_snippet(text)}',
    );
  }

  /// Healthcheck that throws on failure (no silencios).
  Future<void> ensureHealthyBase(
    String baseUrl, {
    List<String>? paths,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final normalized = EngineConfig.normalize(baseUrl);
    if (!EngineConfig.isValidBaseUrl(normalized)) {
      throw const EngineApiDataException('Invalid base URL.');
    }

    final candidates =
        paths ?? const ['/health', '/healthz', '/readyz', '/openapi.json', '/'];
    Object? lastError;

    for (final path in candidates) {
      try {
        await getJsonFromBase(normalized, path, timeout: timeout);
        return;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    throw const EngineApiDataException('Engine healthcheck failed.');
  }

  /// JSON POST for a specific base URL (used by explicit overrides).
  Future<Map<String, dynamic>> postJsonFromBase(
    String baseUrl,
    String path, {
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 12),
    Map<String, String>? headers,
  }) async {
    final normalized = EngineConfig.normalize(baseUrl);
    if (!EngineConfig.isValidBaseUrl(normalized)) {
      throw const EngineApiDataException('Invalid base URL.');
    }

    final base = Uri.parse(normalized);
    final uri = base.replace(path: _joinPath(base.path, path));

    final h = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
      ...?headers,
    };

    final resp = await _client
        .post(uri, headers: h, body: jsonEncode(_stripNulls(body)))
        .timeout(timeout);

    final text = _decodeBody(resp);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EngineApiException(
        statusCode: resp.statusCode,
        url: uri.toString(),
        bodySnippet: _snippet(text),
      );
    }

    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) return decoded;

    throw EngineApiException(
      statusCode: resp.statusCode,
      url: uri.toString(),
      bodySnippet: 'Response is not a JSON object: ${_snippet(text)}',
    );
  }

  /// SmartCalc expression endpoint.
  Future<Map<String, dynamic>> smartCalcExpression(String expression) {
    return postJson(
      '/smart_calc/expression',
      body: {'expression': expression},
      timeout: const Duration(seconds: 10),
    );
  }

  /// Smart editor assistance for a cell.
  Future<Map<String, dynamic>> smartEditCell({
    required String sheetId,
    String? columnName,
    int? rowIndex,
    required String rawValue,
    String? previousValue,
    Map<String, dynamic>? neighborValues,
    Map<String, dynamic>? options,
  }) {
    return postJson(
      '/editor/cell/smart_edit',
      body: <String, dynamic>{
        'sheet_id': sheetId,
        'column_name': columnName,
        'row_index': rowIndex,
        'raw_value': rawValue,
        'previous_value': previousValue,
        'neighbor_values': neighborValues,
        'options': options,
      },
    );
  }

  /// Compute engine (POST /engine/compute).
  Future<Map<String, dynamic>> compute({
    required String sheetId,
    required List<String> headers,
    required List<List<String>> rows,
    String operation = 'calc',
    int? focusRow,
    int? focusCol,
    Map<String, dynamic>? options,
  }) {
    return postJson(
      '/engine/compute',
      body: <String, dynamic>{
        'sheet_id': sheetId,
        'headers': headers,
        'rows': rows,
        'operation': operation,
        'focus_row': focusRow,
        'focus_col': focusCol,
        'options': options,
      },
      timeout: const Duration(seconds: 18),
    );
  }

  /// Export XLSX (flat) -> JSON response with download_url.
  Future<ExportXlsxResponse> exportXlsxFlat({
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
    String sheetName = 'BitFlow',
    bool autoFit = true,
    bool detectLinks = true,
    bool enableFormulas = false,
    String formulaLocale = 'auto',
    bool writeNumbers = false,
  }) async {
    final json = await postJson(
      '/export/xlsx/flat',
      body: <String, dynamic>{
        'file_name': fileName,
        'sheet_name': sheetName,
        'headers': headers,
        'rows': rows,
        'auto_fit': autoFit,
        'detect_links': detectLinks,
        'enable_formulas': enableFormulas,
        'formula_locale': formulaLocale,
        'write_numbers': writeNumbers,
      },
      timeout: const Duration(seconds: 25),
    );
    return ExportXlsxResponse.fromJson(json);
  }

  /// Export XLSX (bitflow with photos) -> JSON response with download_url.
  Future<ExportXlsxResponse> exportXlsxWithPhotos({
    required String fileName,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required int photoColIndex,
    String? title,
    int thumbSize = 80,
    Map<String, String>? meta,
  }) async {
    final json = await postJson(
      '/export/xlsx/bitflow_photos',
      body: <String, dynamic>{
        'file_name': fileName,
        'headers': headers,
        'rows': rows,
        'photo_col_index': photoColIndex,
        'title': title,
        'thumb_size': thumbSize,
        'meta': meta,
      },
      timeout: const Duration(seconds: 40),
    );
    return ExportXlsxResponse.fromJson(json);
  }

  /// Export XLSX bytes (base64 in JSON) -> returns bytes.
  Future<Uint8List> exportXlsxBytes({
    required String fileName,
    required List<String> headers,
    required List<List<String>> rows,
    String sheetName = 'BitFlow',
    bool autoFit = true,
    bool detectLinks = true,
  }) async {
    final json = await postJson(
      '/export/xlsx/bitflow_bytes',
      body: <String, dynamic>{
        'file_name': fileName,
        'sheet_name': sheetName,
        'headers': headers,
        'rows': rows,
        'auto_fit': autoFit,
        'detect_links': detectLinks,
      },
      timeout: const Duration(seconds: 30),
    );

    final ok = json['ok'] == true;
    if (!ok) {
      final message = (json['message'] ?? 'Export failed').toString();
      throw EngineApiDataException(message);
    }

    final b64 = (json['xlsx_base64'] ?? '').toString();
    if (b64.isEmpty) {
      throw const EngineApiDataException('Empty xlsx_base64 in response.');
    }
    return Uint8List.fromList(base64Decode(b64));
  }

  /// Downloads an export URL (absolute or relative) and returns bytes.
  Future<Uint8List> downloadExportBytes(
    String downloadUrl, {
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final uri = await _resolveDownloadUri(downloadUrl);
    final resp = await _client.get(uri).timeout(timeout);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      final text = _decodeBody(resp);
      throw EngineApiException(
        statusCode: resp.statusCode,
        url: uri.toString(),
        bodySnippet: _snippet(text),
      );
    }
    return resp.bodyBytes;
  }

  /// Convenience: downloads and saves a file using platform saver.
  Future<bool> downloadAndSave(
    String downloadUrl, {
    required String fileName,
    String mime =
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  }) async {
    final bytes = await downloadExportBytes(downloadUrl);
    return SaveBytes.save(bytes: bytes, filename: fileName, mime: mime);
  }

  /// If the tunnel changes, call this to re-resolve.
  void resetResolution() {
    _resolvedBase = null;
    _resolving = null;
  }

  Future<bool> _probe(Uri base) async {
    final uri = base.replace(path: _joinPath(base.path, connectProbePath));
    try {
      final resp = await _client.get(uri, headers: const {
        'Accept': 'application/json'
      }).timeout(const Duration(milliseconds: 700));
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<Uri> _buildUri(String path, {bool cacheBust = false}) async {
    final base = await resolveBaseUri();
    final resolvedPath = _joinPath(base.path, path);
    if (!cacheBust) {
      return base.replace(path: resolvedPath);
    }
    return base.replace(
      path: resolvedPath,
      queryParameters: <String, String>{
        'x': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }

  Future<Uri> _resolveDownloadUri(String downloadUrl) async {
    final parsed = Uri.tryParse(downloadUrl.trim());
    if (parsed == null) {
      throw const EngineApiDataException('Invalid download_url.');
    }
    if (parsed.hasScheme) return parsed;
    final base = await resolveBaseUri();
    return base.resolve(downloadUrl);
  }

  static Map<String, dynamic> _stripNulls(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v == null) return;
      out[k] = v;
    });
    return out;
  }

  static String _normalizeBase(String base) {
    var b = base.trim();
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    return b;
  }

  static String _joinPath(String basePath, String path) {
    final bp = basePath.trim();
    final p = path.trim();

    if (bp.isEmpty || bp == '/') {
      return p.startsWith('/') ? p : '/$p';
    }

    final left = bp.endsWith('/') ? bp.substring(0, bp.length - 1) : bp;
    final right = p.startsWith('/') ? p : '/$p';
    return '$left$right';
  }

  static String _decodeBody(http.Response res) {
    try {
      return utf8.decode(res.bodyBytes);
    } catch (_) {
      return res.body;
    }
  }

  static String _snippet(String s) {
    final t = s.replaceAll('\n', ' ').trim();
    if (t.length <= 240) return t;
    return '${t.substring(0, 240)}...';
  }

  void dispose() {
    _client.close();
  }
}

class EngineApiException implements Exception {
  EngineApiException({
    required this.statusCode,
    required this.url,
    required this.bodySnippet,
  });

  final int statusCode;
  final String url;
  final String bodySnippet;

  @override
  String toString() =>
      'EngineApiException(status=$statusCode, url=$url, body="$bodySnippet")';
}

class EngineApiDataException implements Exception {
  const EngineApiDataException(this.message);
  final String message;

  @override
  String toString() => 'EngineApiDataException($message)';
}

class ExportXlsxResponse {
  ExportXlsxResponse({
    required this.ok,
    required this.filePath,
    required this.downloadUrl,
    required this.message,
  });

  final bool ok;
  final String filePath;
  final String downloadUrl;
  final String message;

  factory ExportXlsxResponse.fromJson(Map<String, dynamic> json) {
    return ExportXlsxResponse(
      ok: json['ok'] == true,
      filePath: (json['file_path'] ?? '').toString(),
      downloadUrl: (json['download_url'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
    );
  }
}
