import 'dart:convert';

import 'package:http/http.dart' as http;

enum FlowBotActionType { setCell, fillDown, addRow }

class FlowBotAction {
  const FlowBotAction({
    required this.type,
    this.row,
    this.col,
    this.value,
    this.count,
  });

  final FlowBotActionType type;
  final int? row;
  final int? col;
  final String? value;
  final int? count;

  Map<String, Object?> toJson() => <String, Object?>{
        'type': type.name,
        if (row != null) 'row': row,
        if (col != null) 'col': col,
        if (value != null) 'value': value,
        if (count != null) 'count': count,
      };

  static FlowBotAction? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    final typeRaw = (map['type'] ?? '').toString().trim().toLowerCase();
    final type = switch (typeRaw) {
      'set_cell' || 'setcell' || 'set' || 'write' => FlowBotActionType.setCell,
      'fill_down' || 'filldown' || 'fill' => FlowBotActionType.fillDown,
      'add_row' ||
      'addrow' ||
      'insert_row' ||
      'new_row' =>
        FlowBotActionType.addRow,
      _ => null,
    };
    if (type == null) return null;

    final row = (map['row'] as num?)?.toInt();
    final col = (map['col'] as num?)?.toInt();
    final value = map['value']?.toString();
    final count = (map['count'] as num?)?.toInt();

    switch (type) {
      case FlowBotActionType.setCell:
        if (row == null || col == null) return null;
        return FlowBotAction(
          type: type,
          row: row,
          col: col,
          value: value ?? '',
        );
      case FlowBotActionType.fillDown:
        if (row == null || col == null) return null;
        return FlowBotAction(
          type: type,
          row: row,
          col: col,
          value: value ?? '',
          count: (count == null || count <= 0) ? 1 : count,
        );
      case FlowBotActionType.addRow:
        return const FlowBotAction(type: FlowBotActionType.addRow);
    }
  }
}

class FlowBotParseResult {
  const FlowBotParseResult({
    required this.actions,
    required this.engine,
    this.warning,
  });

  final List<FlowBotAction> actions;
  final String engine;
  final String? warning;

  bool get hasActions => actions.isNotEmpty;
}

class RuleBasedFlowBot {
  const RuleBasedFlowBot();

  FlowBotParseResult parse(
    String raw, {
    required int selectedRow,
    required int selectedCol,
  }) {
    final input = raw.trim();
    if (input.isEmpty) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'rule_based',
        warning: 'Comando vacio.',
      );
    }

    final actions = <FlowBotAction>[];

    final normalized = input.toLowerCase();
    if (_containsAny(
        normalized, const <String>['agregar fila', 'nueva fila'])) {
      actions.add(const FlowBotAction(type: FlowBotActionType.addRow));
    }

    for (final segment in _splitCommands(input)) {
      final cmd = segment.trim();
      if (cmd.isEmpty) continue;

      final setRc = _setByRowColRegex.firstMatch(cmd);
      if (setRc != null) {
        final value = (setRc.group(1) ?? '').trim();
        final row = int.tryParse(setRc.group(2) ?? '');
        final col = int.tryParse(setRc.group(3) ?? '');
        if (row != null && col != null && value.isNotEmpty) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.setCell,
              row: row - 1,
              col: col - 1,
              value: value,
            ),
          );
          continue;
        }
      }

      final setA1 = _setByA1Regex.firstMatch(cmd);
      if (setA1 != null) {
        final value = (setA1.group(1) ?? '').trim();
        final colLabel = (setA1.group(2) ?? '').trim();
        final rowRaw = int.tryParse(setA1.group(3) ?? '');
        final col = _columnLabelToIndex(colLabel);
        if (rowRaw != null && col >= 0 && value.isNotEmpty) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.setCell,
              row: rowRaw - 1,
              col: col,
              value: value,
            ),
          );
          continue;
        }
      }

      final fill = _fillDownRegex.firstMatch(cmd);
      if (fill != null) {
        final value = (fill.group(1) ?? '').trim();
        final count = int.tryParse(fill.group(2) ?? '1') ?? 1;
        if (value.isNotEmpty) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.fillDown,
              row: selectedRow,
              col: selectedCol,
              value: value,
              count: count.clamp(1, 200),
            ),
          );
          continue;
        }
      }

      final setActive = _setActiveRegex.firstMatch(cmd);
      if (setActive != null) {
        final value = (setActive.group(1) ?? '').trim();
        if (value.isNotEmpty) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.setCell,
              row: selectedRow,
              col: selectedCol,
              value: value,
            ),
          );
        }
      }
    }

    return FlowBotParseResult(
      actions: actions,
      engine: 'rule_based',
      warning: actions.isEmpty
          ? 'No se detectaron acciones. Ejemplo: "poner OK en B2".'
          : null,
    );
  }

  bool _containsAny(String text, List<String> tokens) {
    for (final token in tokens) {
      if (text.contains(token)) return true;
    }
    return false;
  }

  List<String> _splitCommands(String raw) {
    final normalized = raw.replaceAll('\n', ';').replaceAll(' y ', ';');
    return normalized.split(';');
  }

  static final RegExp _setByA1Regex = RegExp(
    r'^(?:poner|set|escribir)\s+(.+?)\s+(?:en|at)\s+([A-Za-z]+)(\d+)$',
    caseSensitive: false,
  );

  static final RegExp _setByRowColRegex = RegExp(
    r'^(?:poner|set|escribir)\s+(.+?)\s+(?:en\s+)?fila\s*(\d+)\s*(?:columna|col)\s*(\d+)$',
    caseSensitive: false,
  );

  static final RegExp _fillDownRegex = RegExp(
    r'^(?:rellenar|fill(?:\s+down)?)\s+(.+?)\s+(?:por|x)\s*(\d+)$',
    caseSensitive: false,
  );

  static final RegExp _setActiveRegex = RegExp(
    r'^(?:poner|set|escribir)\s+(.+)$',
    caseSensitive: false,
  );

  int _columnLabelToIndex(String label) {
    final clean = label.trim().toUpperCase();
    if (clean.isEmpty) return -1;
    var col = 0;
    for (final code in clean.codeUnits) {
      if (code < 65 || code > 90) return -1;
      col = (col * 26) + (code - 64);
    }
    return col - 1;
  }
}

class FlowBotLlmEngine {
  FlowBotLlmEngine({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<FlowBotParseResult> parse({
    required String apiKey,
    required String transcript,
    required int selectedRow,
    required int selectedCol,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'llm',
        warning: 'API key vacia.',
      );
    }

    final uri = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = <String, Object?>{
      'model': 'gpt-4o-mini',
      'temperature': 0,
      'response_format': <String, String>{'type': 'json_object'},
      'messages': <Map<String, String>>[
        const <String, String>{
          'role': 'system',
          'content':
              'Convert user command into JSON: {"actions":[{"type":"set_cell|fill_down|add_row","row":0,"col":0,"value":"","count":1}]}. Use 0-based row/col. Return only JSON.',
        },
        <String, String>{
          'role': 'user',
          'content':
              'selected_row=$selectedRow selected_col=$selectedCol command="$transcript"',
        },
      ],
    };

    final response = await _client
        .post(
          uri,
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return FlowBotParseResult(
        actions: const <FlowBotAction>[],
        engine: 'llm',
        warning: 'LLM error HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'llm',
        warning: 'LLM response invalida.',
      );
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'llm',
        warning: 'LLM sin choices.',
      );
    }

    final first = choices.first;
    if (first is! Map) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'llm',
        warning: 'LLM message invalido.',
      );
    }

    final message = first['message'];
    if (message is! Map) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'llm',
        warning: 'LLM message vacio.',
      );
    }

    final content = (message['content'] ?? '').toString().trim();
    if (content.isEmpty) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'llm',
        warning: 'LLM sin contenido.',
      );
    }

    final rawJson = _extractJsonObject(content);
    if (rawJson == null) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'llm',
        warning: 'LLM no devolvio JSON valido.',
      );
    }

    final parsed = jsonDecode(rawJson);
    if (parsed is! Map) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'llm',
        warning: 'JSON invalido.',
      );
    }

    final actionsRaw = parsed['actions'];
    if (actionsRaw is! List) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'llm',
        warning: 'JSON sin acciones.',
      );
    }

    final actions = <FlowBotAction>[];
    for (final item in actionsRaw) {
      final parsedAction = FlowBotAction.fromJson(item);
      if (parsedAction != null) actions.add(parsedAction);
    }

    return FlowBotParseResult(
      actions: actions,
      engine: 'llm',
      warning: actions.isEmpty ? 'LLM sin acciones aplicables.' : null,
    );
  }

  String? _extractJsonObject(String content) {
    final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```')
        .firstMatch(content)
        ?.group(1);
    final candidate = (fenced ?? content).trim();
    final start = candidate.indexOf('{');
    final end = candidate.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return candidate.substring(start, end + 1);
  }
}
