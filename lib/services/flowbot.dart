import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum FlowBotActionType {
  setCell,
  fillRange,
  addRow,
  setColumnAlign,
  setWrap,
  applyStatus,
  setToday,
  autoId,
  copyGps,
  duplicateRow,
  attachPhotoToCell,
  exportPdfPreset,
}

class FlowBotAction {
  const FlowBotAction({
    required this.type,
    this.row,
    this.col,
    this.rowEnd,
    this.colEnd,
    this.column,
    this.value,
    this.count,
    this.align,
    this.lines,
    this.status,
    this.format,
    this.start,
    this.step,
    this.fromRow,
    this.presetId,
  });

  final FlowBotActionType type;
  final int? row;
  final int? col;
  final int? rowEnd;
  final int? colEnd;
  final int? column;
  final String? value;
  final int? count;
  final String? align;
  final int? lines;
  final String? status;
  final String? format;
  final int? start;
  final int? step;
  final int? fromRow;
  final String? presetId;

  Map<String, Object?> toJson() => <String, Object?>{
        'type': type.name,
        if (row != null) 'row': row,
        if (col != null) 'col': col,
        if (rowEnd != null) 'rowEnd': rowEnd,
        if (colEnd != null) 'colEnd': colEnd,
        if (column != null) 'column': column,
        if (value != null) 'value': value,
        if (count != null) 'count': count,
        if (align != null) 'align': align,
        if (lines != null) 'lines': lines,
        if (status != null) 'status': status,
        if (format != null) 'format': format,
        if (start != null) 'start': start,
        if (step != null) 'step': step,
        if (fromRow != null) 'fromRow': fromRow,
        if (presetId != null) 'presetId': presetId,
      };

  static FlowBotAction? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final map = raw.cast<Object?, Object?>();
    final typeRaw = (map['type'] ?? '').toString().trim().toLowerCase();
    final type = switch (typeRaw) {
      'set_cell' || 'setcell' || 'set' || 'write' => FlowBotActionType.setCell,
      'fill_down' ||
      'filldown' ||
      'fill' ||
      'fill_range' ||
      'fillrange' =>
        FlowBotActionType.fillRange,
      'add_row' ||
      'addrow' ||
      'insert_row' ||
      'new_row' =>
        FlowBotActionType.addRow,
      'set_column_align' ||
      'setcolumnalign' ||
      'column_align' =>
        FlowBotActionType.setColumnAlign,
      'set_wrap' || 'setwrap' || 'wrap' => FlowBotActionType.setWrap,
      'apply_status' || 'status' => FlowBotActionType.applyStatus,
      'set_today' || 'today' => FlowBotActionType.setToday,
      'auto_id' || 'autoid' => FlowBotActionType.autoId,
      'copy_gps' || 'copygps' => FlowBotActionType.copyGps,
      'duplicate_row' || 'duplicaterow' => FlowBotActionType.duplicateRow,
      'attach_photo_to_cell' ||
      'attachphoto' =>
        FlowBotActionType.attachPhotoToCell,
      'export_pdf_preset' || 'exportpdf' => FlowBotActionType.exportPdfPreset,
      _ => null,
    };
    if (type == null) return null;

    final row = (map['row'] as num?)?.toInt();
    final col = (map['col'] as num?)?.toInt();
    final rowEnd = (map['rowEnd'] as num?)?.toInt();
    final colEnd = (map['colEnd'] as num?)?.toInt();
    final column = (map['column'] as num?)?.toInt();
    final value = map['value']?.toString();
    final count = (map['count'] as num?)?.toInt();
    final align = map['align']?.toString();
    final lines = (map['lines'] as num?)?.toInt();
    final status = map['status']?.toString();
    final format = map['format']?.toString();
    final start = (map['start'] as num?)?.toInt();
    final step = (map['step'] as num?)?.toInt();
    final fromRow = (map['fromRow'] as num?)?.toInt();
    final presetId = map['presetId']?.toString();

    switch (type) {
      case FlowBotActionType.setCell:
        if (row == null || col == null) return null;
        return FlowBotAction(
          type: type,
          row: row,
          col: col,
          value: value ?? '',
        );
      case FlowBotActionType.fillRange:
        if (row == null || col == null) return null;
        return FlowBotAction(
          type: type,
          row: row,
          col: col,
          count: (count == null || count <= 0) ? 1 : count,
          value: value ?? '',
          rowEnd: rowEnd,
          colEnd: colEnd,
        );
      case FlowBotActionType.addRow:
        return FlowBotAction(type: type, count: (count ?? 1).clamp(1, 500));
      case FlowBotActionType.setColumnAlign:
        if (column == null || (align ?? '').trim().isEmpty) return null;
        return FlowBotAction(type: type, column: column, align: align);
      case FlowBotActionType.setWrap:
        if (column == null || lines == null) return null;
        return FlowBotAction(type: type, column: column, lines: lines);
      case FlowBotActionType.applyStatus:
        if ((status ?? '').trim().isEmpty) return null;
        return FlowBotAction(type: type, status: status);
      case FlowBotActionType.setToday:
        return FlowBotAction(type: type, format: format);
      case FlowBotActionType.autoId:
        return FlowBotAction(type: type, start: start, step: step);
      case FlowBotActionType.copyGps:
        return FlowBotAction(type: type, fromRow: fromRow);
      case FlowBotActionType.duplicateRow:
        return FlowBotAction(
          type: type,
          row: row,
          count: (count ?? 1).clamp(1, 100),
        );
      case FlowBotActionType.attachPhotoToCell:
        return FlowBotAction(type: type, row: row, col: col);
      case FlowBotActionType.exportPdfPreset:
        return FlowBotAction(type: type, presetId: presetId);
    }
  }

  static List<FlowBotAction> parseActionsList(Object? raw) {
    if (raw is! List) return const <FlowBotAction>[];
    final out = <FlowBotAction>[];
    for (final item in raw) {
      final action = FlowBotAction.fromJson(item);
      if (action != null) out.add(action);
    }
    return out;
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
    List<int>? selectedRows,
    int maxRows = 50000,
    int maxCols = 200,
  }) {
    final input = raw.trim();
    if (input.isEmpty) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'rule_based',
        warning: 'Comando vacio.',
      );
    }

    final rows = (selectedRows == null || selectedRows.isEmpty)
        ? <int>[selectedRow]
        : (List<int>.from(selectedRows)..sort());
    final firstRow = rows.first.clamp(0, maxRows - 1);

    final actions = <FlowBotAction>[];
    final normalized = input.toLowerCase();

    if (_containsAny(
        normalized, const <String>['agregar fila', 'nueva fila'])) {
      actions
          .add(const FlowBotAction(type: FlowBotActionType.addRow, count: 1));
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
        final col = _columnTokenToIndex(colLabel);
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

      final fill = _fillRangeRegex.firstMatch(cmd);
      if (fill != null) {
        final value = (fill.group(1) ?? '').trim();
        final countRaw = int.tryParse(fill.group(2) ?? '') ?? rows.length;
        if (value.isNotEmpty) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.fillRange,
              row: firstRow,
              col: selectedCol,
              count: countRaw.clamp(1, 500),
              value: value,
              rowEnd: rows.last,
              colEnd: selectedCol,
            ),
          );
          continue;
        }
      }

      final align = _setAlignRegex.firstMatch(cmd);
      if (align != null) {
        final columnToken = (align.group(1) ?? '').trim();
        final alignToken = (align.group(2) ?? '').trim().toLowerCase();
        final column = columnToken.isEmpty
            ? selectedCol
            : _columnTokenToIndex(columnToken);
        final normalizedAlign = _normalizeAlign(alignToken);
        if (column >= 0 && normalizedAlign != null) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.setColumnAlign,
              column: column,
              align: normalizedAlign,
            ),
          );
          continue;
        }
      }

      final wrap = _setWrapRegex.firstMatch(cmd);
      if (wrap != null) {
        final columnToken = (wrap.group(1) ?? '').trim();
        final linesRaw = int.tryParse(wrap.group(2) ?? '2') ?? 2;
        final column = columnToken.isEmpty
            ? selectedCol
            : _columnTokenToIndex(columnToken);
        if (column >= 0) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.setWrap,
              column: column,
              lines: linesRaw.clamp(1, 3),
            ),
          );
          continue;
        }
      }

      final status = _statusRegex.firstMatch(cmd);
      if (status != null) {
        final statusValue = (status.group(1) ?? '').trim();
        if (statusValue.isNotEmpty) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.applyStatus,
              status: _normalizeStatus(statusValue),
            ),
          );
          continue;
        }
      }

      final setToday = _setTodayRegex.firstMatch(cmd);
      if (setToday != null) {
        final format = (setToday.group(1) ?? '').trim();
        actions.add(
          FlowBotAction(
            type: FlowBotActionType.setToday,
            format: format.isEmpty ? null : format,
          ),
        );
        continue;
      }

      final autoId = _autoIdRegex.firstMatch(cmd);
      if (autoId != null) {
        final start = int.tryParse(autoId.group(1) ?? '');
        final step = int.tryParse(autoId.group(2) ?? '');
        actions.add(
          FlowBotAction(
            type: FlowBotActionType.autoId,
            start: start,
            step: step,
          ),
        );
        continue;
      }

      final copyGps = _copyGpsRegex.firstMatch(cmd);
      if (copyGps != null) {
        final source =
            int.tryParse((copyGps.group(1) ?? copyGps.group(2) ?? '').trim());
        actions.add(
          FlowBotAction(
            type: FlowBotActionType.copyGps,
            fromRow: source == null ? null : source - 1,
          ),
        );
        continue;
      }

      final duplicate = _duplicateRowRegex.firstMatch(cmd);
      if (duplicate != null) {
        final row = int.tryParse((duplicate.group(1) ?? '').trim());
        final count = int.tryParse((duplicate.group(2) ?? '').trim()) ?? 1;
        actions.add(
          FlowBotAction(
            type: FlowBotActionType.duplicateRow,
            row: (row ?? selectedRow + 1) - 1,
            count: count.clamp(1, 100),
          ),
        );
        continue;
      }

      final attachPhoto = _attachPhotoRegex.firstMatch(cmd);
      if (attachPhoto != null) {
        final token = (attachPhoto.group(1) ?? '').trim();
        if (token.isNotEmpty) {
          final a1 = _a1CellRegex.firstMatch(token);
          if (a1 != null) {
            final c = _columnTokenToIndex((a1.group(1) ?? '').trim());
            final r = int.tryParse(a1.group(2) ?? '');
            if (c >= 0 && r != null) {
              actions.add(
                FlowBotAction(
                  type: FlowBotActionType.attachPhotoToCell,
                  row: r - 1,
                  col: c,
                ),
              );
              continue;
            }
          }
        }
        actions.add(
          FlowBotAction(
            type: FlowBotActionType.attachPhotoToCell,
            row: selectedRow,
            col: selectedCol,
          ),
        );
        continue;
      }

      final exportPdf = _exportPdfRegex.firstMatch(cmd);
      if (exportPdf != null) {
        final preset = (exportPdf.group(1) ?? 'default').trim().toLowerCase();
        actions.add(
          FlowBotAction(
            type: FlowBotActionType.exportPdfPreset,
            presetId: preset.isEmpty ? 'default' : preset,
          ),
        );
        continue;
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
    final normalized = raw
        .replaceAll('\n', ';')
        .replaceAll(' y luego ', ';')
        .replaceAll(' y ', ';');
    return normalized.split(';');
  }

  String? _normalizeAlign(String raw) {
    switch (raw) {
      case 'izquierda':
      case 'left':
        return 'left';
      case 'centro':
      case 'center':
      case 'centrado':
        return 'center';
      case 'derecha':
      case 'right':
        return 'right';
      default:
        return null;
    }
  }

  String _normalizeStatus(String raw) {
    final lowered = raw.toLowerCase();
    if (lowered.startsWith('urg')) return 'Urgente';
    if (lowered.startsWith('obs')) return 'Obs';
    if (lowered.startsWith('ok')) return 'OK';
    if (lowered.startsWith('pen')) return 'Pendiente';
    return raw;
  }

  int _columnTokenToIndex(String token) {
    final clean = token.trim().toUpperCase();
    if (clean.isEmpty) return -1;

    final numeric = int.tryParse(clean);
    if (numeric != null) return numeric - 1;

    var col = 0;
    for (final code in clean.codeUnits) {
      if (code < 65 || code > 90) return -1;
      col = (col * 26) + (code - 64);
    }
    return col - 1;
  }

  static final RegExp _setByA1Regex = RegExp(
    r'^(?:poner|set|escribir)\s+(.+?)\s+(?:en|at)\s+([A-Za-z]+)(\d+)$',
    caseSensitive: false,
  );

  static final RegExp _setByRowColRegex = RegExp(
    r'^(?:poner|set|escribir)\s+(.+?)\s+(?:en\s+)?fila\s*(\d+)\s*(?:columna|col)\s*(\d+)$',
    caseSensitive: false,
  );

  static final RegExp _fillRangeRegex = RegExp(
    r'^(?:rellenar|fill(?:\s+down)?)\s+(.+?)(?:\s+(?:por|x)\s*(\d+))?$',
    caseSensitive: false,
  );

  static final RegExp _setAlignRegex = RegExp(
    r'^(?:alinear|align)(?:\s+columna)?\s*([A-Za-z]+|\d+)?\s*(?:a\s*)?(izquierda|centro|centrado|derecha|left|center|right)$',
    caseSensitive: false,
  );

  static final RegExp _setWrapRegex = RegExp(
    r'^(?:wrap|ajuste|ajustar)(?:\s+columna)?\s*([A-Za-z]+|\d+)?\s*(?:a\s*)?(1|2|3)?(?:\s*lineas?)?$',
    caseSensitive: false,
  );

  static final RegExp _statusRegex = RegExp(
    r'^(?:estado|status)\s+(ok|obs|urgente|pendiente)$',
    caseSensitive: false,
  );

  static final RegExp _setTodayRegex = RegExp(
    r'^(?:hoy|fecha hoy|set today)(?:\s+formato\s+([a-zA-Z0-9:/._-]+))?$',
    caseSensitive: false,
  );

  static final RegExp _autoIdRegex = RegExp(
    r'^(?:autoid|id auto|autoid)(?:\s+desde\s*(\d+))?(?:\s+paso\s*(\d+))?$',
    caseSensitive: false,
  );

  static final RegExp _copyGpsRegex = RegExp(
    r'^(?:copiar\s+gps(?:\s+de\s+fila\s*(\d+))?|gps\s+fila\s*(\d+)\s+a\s+seleccion)$',
    caseSensitive: false,
  );

  static final RegExp _duplicateRowRegex = RegExp(
    r'^(?:duplicar\s+fila\s*(\d+)?(?:\s*(?:x|por)\s*(\d+))?)$',
    caseSensitive: false,
  );

  static final RegExp _attachPhotoRegex = RegExp(
    r'^(?:adjuntar\s+foto(?:\s+en\s+([A-Za-z]+\d+))?)$',
    caseSensitive: false,
  );

  static final RegExp _exportPdfRegex = RegExp(
    r'^(?:exportar\s+pdf(?:\s+([a-zA-Z0-9_-]+))?)$',
    caseSensitive: false,
  );

  static final RegExp _setActiveRegex = RegExp(
    r'^(?:poner|set|escribir)\s+(.+)$',
    caseSensitive: false,
  );

  static final RegExp _a1CellRegex = RegExp(r'^([A-Za-z]+)(\d+)$');
}

class FlowBotLocalLlmEngine {
  FlowBotLocalLlmEngine({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('bitflow/flowbot_local_llm');

  final MethodChannel _channel;

  Future<FlowBotParseResult> parse({
    required String modelPath,
    required String transcript,
    required int selectedRow,
    required int selectedCol,
    required List<int> selectedRows,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final command = transcript.trim();
    final model = modelPath.trim();
    if (command.isEmpty) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'local_llm',
        warning: 'Comando vacio.',
      );
    }
    if (model.isEmpty) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'local_llm',
        warning: 'No hay modelo local instalado.',
      );
    }
    if (kIsWeb) {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'local_llm',
        warning: 'Local LLM no disponible en Web (usar motor offline).',
      );
    }

    try {
      final raw =
          await _channel.invokeMethod<Object?>('parse', <String, Object?>{
        'modelPath': model,
        'command': command,
        'selectedRow': selectedRow,
        'selectedCol': selectedCol,
        'selectedRows': selectedRows,
      }).timeout(timeout);

      if (raw == null) {
        return const FlowBotParseResult(
          actions: <FlowBotAction>[],
          engine: 'local_llm',
          warning: 'Local LLM no devolvio respuesta.',
        );
      }

      Object? decoded = raw;
      if (raw is String) {
        decoded = jsonDecode(raw);
      }
      if (decoded is! Map) {
        return const FlowBotParseResult(
          actions: <FlowBotAction>[],
          engine: 'local_llm',
          warning: 'Respuesta local invalida.',
        );
      }

      final actions = FlowBotAction.parseActionsList(decoded['actions']);
      final warning = (decoded['warning'] ?? '').toString().trim();
      return FlowBotParseResult(
        actions: actions,
        engine: 'local_llm',
        warning: warning.isEmpty
            ? (actions.isEmpty ? 'Local LLM sin acciones aplicables.' : null)
            : warning,
      );
    } on MissingPluginException {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'local_llm',
        warning: 'Runtime local LLM no instalado; usando motor offline.',
      );
    } on TimeoutException {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'local_llm',
        warning: 'Local LLM timeout; usando motor offline.',
      );
    } catch (e) {
      return FlowBotParseResult(
        actions: const <FlowBotAction>[],
        engine: 'local_llm',
        warning: 'Local LLM error: $e',
      );
    }
  }
}
