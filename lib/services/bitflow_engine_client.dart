import 'dart:convert';
import 'package:http/http.dart' as http;

/// URL por defecto cuando se usa la notebook/PC en LAN.
const String _defaultLanUrl = 'http://192.168.1.45:8000';

/// URL por defecto para el túnel Cloudflare (quick tunnel actual).
/// Cada vez que generes un túnel nuevo, podés cambiar esta constante
/// o bien usar --dart-define=PY_ENGINE_URL=...
const String _defaultTunnelUrl =
    'https://dock-stranger-crossing-breeding.trycloudflare.com';

/// Flag de build para decidir si se usa túnel por defecto o LAN.
///
/// Ejemplo:
///   flutter run -d chrome --dart-define=USE_TUNNEL=true
const bool _useTunnelByDefault =
    bool.fromEnvironment('USE_TUNNEL', defaultValue: false);

/// Excepción genérica al hablar con el motor Python BitFlow Engine.
class BitflowEngineException implements Exception {
  final String message;
  final int? statusCode;

  BitflowEngineException(this.message, {this.statusCode});

  @override
  String toString() =>
      'BitflowEngineException(statusCode: $statusCode, message: $message)';
}

/// Celda modificada por el motor en /engine/compute.
class EngineUpdatedCell {
  final int row;
  final int col;
  final String value;

  const EngineUpdatedCell({
    required this.row,
    required this.col,
    required this.value,
  });

  factory EngineUpdatedCell.fromJson(Map<String, dynamic> json) {
    return EngineUpdatedCell(
      row: json['row'] as int,
      col: json['col'] as int,
      value: json['value'] as String,
    );
  }
}

/// Respuesta de /engine/compute (motor genérico).
class EngineComputeResponse {
  final List<EngineUpdatedCell> updatedCells;
  final String? message;

  const EngineComputeResponse({
    required this.updatedCells,
    required this.message,
  });

  factory EngineComputeResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['updated_cells'] as List<dynamic>? ?? const [];
    final cells = raw
        .whereType<Map<String, dynamic>>()
        .map((e) => EngineUpdatedCell.fromJson(e))
        .toList();

    return EngineComputeResponse(
      updatedCells: cells,
      message: json['message'] as String?,
    );
  }

  bool get hasUpdates => updatedCells.isNotEmpty;
}

/// Cliente HTTP para hablar con el backend Python BitFlow / Cathodic / XLSX Engine.
///
/// Alineado con el main.py actual:
///   - POST /engine/compute  (operation: "calc", "tank_anodes",
///                            "cathodic_analyze", "grounding_analyze",
///                            "cp_design_current")
///
/// El baseUrl puede apuntar tanto a:
///   - LAN:  http://192.168.1.45:8000
///   - Túnel Cloudflare: https://lo-que-sea.trycloudflare.com
class BitflowEngineClient {
  BitflowEngineClient({
    required this.baseUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  /// URL base del engine (ej: 'http://192.168.1.45:8000' o túnel Cloudflare).
  final String baseUrl;
  final http.Client _httpClient;

  Uri _buildUri(String path) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  String _decodeUtf8Body(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return response.body;
    }
  }

  Future<Map<String, dynamic>> _postJson(
    Uri uri,
    Map<String, Object?> payload,
  ) async {
    final body = jsonEncode(payload);

    http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 25));
    } on Exception catch (e) {
      throw BitflowEngineException(
        'No se pudo conectar a BitFlow Engine: $e',
      );
    }

    final String bodyString = _decodeUtf8Body(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BitflowEngineException(
        'Error HTTP desde BitFlow Engine: $bodyString',
        statusCode: response.statusCode,
      );
    }

    // Decode robusto (acentos, caracteres especiales, etc.).

    final dynamic decoded;
    try {
      decoded = jsonDecode(bodyString);
    } on FormatException catch (e) {
      throw BitflowEngineException(
        'Respuesta inválida de BitFlow Engine (JSON malformado): $e',
        statusCode: response.statusCode,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw BitflowEngineException(
        'Respuesta inesperada de BitFlow Engine (no es JSON objeto).',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  /// Llama a /engine/compute.
  ///
  /// - [sheetId]: identificador lógico de la hoja (obra/campaña).
  /// - [headers]: encabezados de la tabla (títulos de columnas).
  /// - [rows]: filas de datos (`List<List<String>>` normalmente).
  /// - [operation]: "calc", "tank_anodes", "cathodic_analyze",
  ///                "grounding_analyze", "cp_design_current", etc.
  /// - [focusRow]/[focusCol]: celda activa en la UI (opcional).
  /// - [options]: campo extra libre para futuras opciones.
  Future<EngineComputeResponse> compute({
    required String sheetId,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required String operation,
    int? focusRow,
    int? focusCol,
    Map<String, dynamic>? options,
  }) async {
    final uri = _buildUri('/engine/compute');

    // Normalizamos rows a List<List<String>> para mandarle al engine algo estable.
    final normalizedRows = rows
        .map<List<String>>(
          (row) => row
              .map<String>((cell) => cell == null ? '' : cell.toString())
              .toList(growable: false),
        )
        .toList(growable: false);

    final payload = <String, Object?>{
      'sheet_id': sheetId,
      'headers': headers,
      'rows': normalizedRows,
      'operation': operation,
      if (focusRow != null) 'focus_row': focusRow,
      if (focusCol != null) 'focus_col': focusCol,
      if (options != null && options.isNotEmpty) 'options': options,
    };

    final json = await _postJson(uri, payload);
    return EngineComputeResponse.fromJson(json);
  }

  /// Atajo para el motor genérico "calc" (sumatoria TOTAL por fila u otras reglas).
  Future<EngineComputeResponse> calcTotals({
    required String sheetId,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    return compute(
      sheetId: sheetId,
      headers: headers,
      rows: rows,
      operation: 'calc',
    );
  }

  /// Atajo para 'tank_anodes' (cálculo de cantidad de ánodos de tanque).
  Future<EngineComputeResponse> tankAnodes({
    required String sheetId,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    return compute(
      sheetId: sheetId,
      headers: headers,
      rows: rows,
      operation: 'tank_anodes',
    );
  }

  /// Atajo para 'cathodic_analyze' desde una planilla genérica.
  ///
  /// OJO: hoy el backend usa el criterio fijo de -850 mV en /engine/compute;
  /// este [offCriterionMv] se manda en options por si en el futuro se lee ahí.
  Future<EngineComputeResponse> cathodicAnalyzeFromSheet({
    required String sheetId,
    required List<String> headers,
    required List<List<dynamic>> rows,
    double offCriterionMv = -850.0,
  }) {
    return compute(
      sheetId: sheetId,
      headers: headers,
      rows: rows,
      operation: 'cathodic_analyze',
      options: <String, dynamic>{
        'off_criterion_mv': offCriterionMv,
      },
    );
  }

  /// Atajo para 'grounding_analyze' (puesta a tierra).
  Future<EngineComputeResponse> groundingAnalyzeFromSheet({
    required String sheetId,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    return compute(
      sheetId: sheetId,
      headers: headers,
      rows: rows,
      operation: 'grounding_analyze',
    );
  }

  /// Atajo para 'cp_design_current' (corriente de diseño de CP).
  Future<EngineComputeResponse> cpDesignCurrentFromSheet({
    required String sheetId,
    required List<String> headers,
    required List<List<dynamic>> rows,
    int roundDecimals = 3,
  }) {
    return compute(
      sheetId: sheetId,
      headers: headers,
      rows: rows,
      operation: 'cp_design_current',
      options: <String, dynamic>{
        'round_decimals': roundDecimals,
      },
    );
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Helper para crear un cliente apuntando al engine.
///
/// Prioridad:
///  1) --dart-define=PY_ENGINE_URL=…          (URL completa, LAN o túnel)
///  2) --dart-define=BITFLOW_ENGINE_URL=…     (compat viejo)
///  3) Por defecto:
///       - Si USE_TUNNEL=true  → _defaultTunnelUrl
///       - Si USE_TUNNEL=false → _defaultLanUrl
BitflowEngineClient createDefaultBitflowEngineClient() {
  const pyUrl = String.fromEnvironment('PY_ENGINE_URL');
  const legacyUrl = String.fromEnvironment('BITFLOW_ENGINE_URL');

  final baseUrl = pyUrl.isNotEmpty
      ? pyUrl
      : (legacyUrl.isNotEmpty
          ? legacyUrl
          : (_useTunnelByDefault ? _defaultTunnelUrl : _defaultLanUrl));

  return BitflowEngineClient(baseUrl: baseUrl);
}
