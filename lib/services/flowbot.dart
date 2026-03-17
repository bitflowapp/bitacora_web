import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum FlowBotActionType {
  setCell,
  fillRange,
  addRow,
  clearSelection,
  clearRow,
  setColumnAlign,
  setWrap,
  applyStatus,
  setToday,
  autoId,
  copyGps,
  duplicateRow,
  attachPhotoToCell,
  exportPdfPreset,
  pasteTable,
  exportBundle,
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
    final map = _asStringKeyMap(raw);
    if (map == null) return null;

    final type = _parseActionType(map['type']);
    if (type == null) return null;

    final row = _toInt(map['row']);
    final col = _toInt(map['col']);
    final rowEnd = _toInt(map['rowEnd']);
    final colEnd = _toInt(map['colEnd']);
    final column = _toInt(map['column']);
    final value = _toTrimmedStringOrNull(map['value']);
    final count = _toInt(map['count']);
    final align = _toTrimmedStringOrNull(map['align']);
    final lines = _toInt(map['lines']);
    final status = _toTrimmedStringOrNull(map['status']);
    final format = _toTrimmedStringOrNull(map['format']);
    final start = _toInt(map['start']);
    final step = _toInt(map['step']);
    final fromRow = _toInt(map['fromRow']);
    final presetId = _toTrimmedStringOrNull(map['presetId']);

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
        return FlowBotAction(
          type: type,
          count: (count ?? 1).clamp(1, 500),
          value: value,
        );

      case FlowBotActionType.clearSelection:
        return const FlowBotAction(type: FlowBotActionType.clearSelection);

      case FlowBotActionType.clearRow:
        return const FlowBotAction(type: FlowBotActionType.clearRow);

      case FlowBotActionType.setColumnAlign:
        if (column == null || (align ?? '').isEmpty) return null;
        return FlowBotAction(type: type, column: column, align: align);

      case FlowBotActionType.setWrap:
        if (column == null || lines == null) return null;
        return FlowBotAction(
          type: type,
          column: column,
          lines: lines.clamp(1, 3),
        );

      case FlowBotActionType.applyStatus:
        if ((status ?? '').isEmpty) return null;
        return FlowBotAction(type: type, status: status);

      case FlowBotActionType.setToday:
        return FlowBotAction(type: type, format: format, value: value);

      case FlowBotActionType.autoId:
        return FlowBotAction(
          type: type,
          start: start,
          step: step,
          count: count,
          column: column,
        );

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

      case FlowBotActionType.pasteTable:
        return const FlowBotAction(type: FlowBotActionType.pasteTable);

      case FlowBotActionType.exportBundle:
        return const FlowBotAction(type: FlowBotActionType.exportBundle);
    }
  }

  static List<FlowBotAction> parseActionsList(
      Object? raw, {
        int maxActions = 50,
      }) {
    if (raw is! List) return const <FlowBotAction>[];
    if (maxActions <= 0) return const <FlowBotAction>[];

    final out = <FlowBotAction>[];
    for (final item in raw) {
      final action = FlowBotAction.fromJson(item);
      if (action != null) {
        out.add(action);
        if (out.length >= maxActions) break;
      }
    }
    return out;
  }

  static FlowBotActionType? _parseActionType(Object? raw) {
    final typeRaw = _toTrimmedStringOrNull(raw)?.toLowerCase() ?? '';
    switch (typeRaw) {
      case 'set_cell':
      case 'setcell':
      case 'set':
      case 'write':
        return FlowBotActionType.setCell;

      case 'fill_down':
      case 'filldown':
      case 'fill':
      case 'fill_range':
      case 'fillrange':
        return FlowBotActionType.fillRange;

      case 'add_row':
      case 'addrow':
      case 'insert_row':
      case 'new_row':
        return FlowBotActionType.addRow;

      case 'clear_selection':
      case 'clearselection':
        return FlowBotActionType.clearSelection;

      case 'clear_row':
      case 'clearrow':
        return FlowBotActionType.clearRow;

      case 'set_column_align':
      case 'setcolumnalign':
      case 'column_align':
        return FlowBotActionType.setColumnAlign;

      case 'set_wrap':
      case 'setwrap':
      case 'wrap':
        return FlowBotActionType.setWrap;

      case 'apply_status':
      case 'status':
        return FlowBotActionType.applyStatus;

      case 'set_today':
      case 'today':
        return FlowBotActionType.setToday;

      case 'auto_id':
      case 'autoid':
        return FlowBotActionType.autoId;

      case 'copy_gps':
      case 'copygps':
        return FlowBotActionType.copyGps;

      case 'duplicate_row':
      case 'duplicaterow':
        return FlowBotActionType.duplicateRow;

      case 'attach_photo_to_cell':
      case 'attachphoto':
        return FlowBotActionType.attachPhotoToCell;

      case 'export_pdf_preset':
      case 'exportpdf':
        return FlowBotActionType.exportPdfPreset;

      case 'paste_table':
      case 'pastetable':
        return FlowBotActionType.pasteTable;

      case 'export_bundle':
      case 'exportbundle':
        return FlowBotActionType.exportBundle;

      default:
        return null;
    }
  }

  static Map<String, Object?>? _asStringKeyMap(Object? raw) {
    if (raw is Map<String, Object?>) return raw;
    if (raw is Map) {
      return raw.map(
            (key, value) => MapEntry(key.toString(), value),
      );
    }
    return null;
  }

  static int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }

  static String? _toTrimmedStringOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
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
        warning: 'Comando vacío.',
      );
    }

    final safeMaxRows = maxRows <= 0 ? 1 : maxRows;
    final safeMaxCols = maxCols <= 0 ? 1 : maxCols;

    final clampedSelectedRow = selectedRow.clamp(0, safeMaxRows - 1);
    final clampedSelectedCol = selectedCol.clamp(0, safeMaxCols - 1);

    final rows = _normalizeSelectedRows(
      selectedRows,
      fallbackRow: clampedSelectedRow,
      maxRows: safeMaxRows,
    );
    final firstRow = rows.first;

    final actions = <FlowBotAction>[];
    final normalized = input.toLowerCase();
    var parseInput = input;

    final newRowWithValues = _newRowWithValuesRegex.firstMatch(input);
    if (newRowWithValues != null) {
      final payload = (newRowWithValues.group(1) ?? '').trim();
      actions.add(
        FlowBotAction(
          type: FlowBotActionType.addRow,
          count: 1,
          value: payload,
        ),
      );
      parseInput = input.replaceFirst(newRowWithValues.group(0)!, '').trim();
    }

    if (_containsAny(normalized, const <String>[
      'agregar fila',
      'nueva fila',
      'fila nueva',
      'nuevo registro',
      'agregá fila',
      'agrega fila',
    ]) &&
        newRowWithValues == null) {
      actions.add(
        const FlowBotAction(
          type: FlowBotActionType.addRow,
          count: 1,
        ),
      );
    }

    for (final segment in _splitCommands(parseInput)) {
      final cmd = segment.trim();
      if (cmd.isEmpty) continue;

      final clearSelection = _clearSelectionRegex.firstMatch(cmd);
      if (clearSelection != null) {
        actions.add(
          const FlowBotAction(type: FlowBotActionType.clearSelection),
        );
        continue;
      }

      final clearRow = _clearRowRegex.firstMatch(cmd);
      if (clearRow != null) {
        actions.add(
          const FlowBotAction(type: FlowBotActionType.clearRow),
        );
        continue;
      }

      final fillSeries = _fillSeriesRegex.firstMatch(cmd);
      if (fillSeries != null) {
        final start = int.tryParse(fillSeries.group(1) ?? '') ?? 1;
        final step = int.tryParse(fillSeries.group(2) ?? '') ?? 1;
        final count =
            int.tryParse(fillSeries.group(3) ?? '') ?? rows.length.clamp(1, 500);

        actions.add(
          FlowBotAction(
            type: FlowBotActionType.autoId,
            start: start,
            step: step == 0 ? 1 : step,
            count: count.clamp(1, 500),
          ),
        );
        continue;
      }

      final autonumber = _autonumberRegex.firstMatch(cmd);
      if (autonumber != null) {
        final start = int.tryParse(autonumber.group(1) ?? '') ?? 1;
        final step = int.tryParse(autonumber.group(2) ?? '') ?? 1;

        actions.add(
          FlowBotAction(
            type: FlowBotActionType.autoId,
            start: start,
            step: step == 0 ? 1 : step,
          ),
        );
        continue;
      }

      final setRc = _setByRowColRegex.firstMatch(cmd);
      if (setRc != null) {
        final value = (setRc.group(1) ?? '').trim();
        final rowRaw = int.tryParse(setRc.group(2) ?? '');
        final colRaw = int.tryParse(setRc.group(3) ?? '');
        final row = _rowNumberToIndex(rowRaw, safeMaxRows);
        final col = _columnNumberToIndex(colRaw, safeMaxCols);

        if (row != null && col != null && value.isNotEmpty) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.setCell,
              row: row,
              col: col,
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
        final row = _rowNumberToIndex(rowRaw, safeMaxRows);
        final col = _columnTokenToIndex(colLabel, maxCols: safeMaxCols);

        if (row != null && col != null && value.isNotEmpty) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.setCell,
              row: row,
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
              col: clampedSelectedCol,
              count: countRaw.clamp(1, 500),
              value: value,
              rowEnd: rows.last,
              colEnd: clampedSelectedCol,
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
            ? clampedSelectedCol
            : _columnTokenToIndex(columnToken, maxCols: safeMaxCols);
        final normalizedAlign = _normalizeAlign(alignToken);

        if (column != null && normalizedAlign != null) {
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
            ? clampedSelectedCol
            : _columnTokenToIndex(columnToken, maxCols: safeMaxCols);
        if (column != null) {
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
        final scope = (setToday.group(2) ?? '').trim().toLowerCase();
        actions.add(
          FlowBotAction(
            type: FlowBotActionType.setToday,
            format: format.isEmpty ? null : format,
            value: scope.isEmpty ? null : scope,
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
            step: step == null || step == 0 ? null : step,
          ),
        );
        continue;
      }

      final copyGps = _copyGpsRegex.firstMatch(cmd);
      if (copyGps != null) {
        final source =
        int.tryParse((copyGps.group(1) ?? copyGps.group(2) ?? '').trim());
        final fromRow = _rowNumberToIndex(source, safeMaxRows);
        actions.add(
          FlowBotAction(
            type: FlowBotActionType.copyGps,
            fromRow: fromRow,
          ),
        );
        continue;
      }

      final duplicate = _duplicateRowRegex.firstMatch(cmd);
      if (duplicate != null) {
        final rowRaw = int.tryParse((duplicate.group(1) ?? '').trim());
        final row = _rowNumberToIndex(rowRaw, safeMaxRows) ?? clampedSelectedRow;
        final count = int.tryParse((duplicate.group(2) ?? '').trim()) ?? 1;

        actions.add(
          FlowBotAction(
            type: FlowBotActionType.duplicateRow,
            row: row,
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
            final c = _columnTokenToIndex(
              (a1.group(1) ?? '').trim(),
              maxCols: safeMaxCols,
            );
            final r = _rowNumberToIndex(
              int.tryParse(a1.group(2) ?? ''),
              safeMaxRows,
            );
            if (c != null && r != null) {
              actions.add(
                FlowBotAction(
                  type: FlowBotActionType.attachPhotoToCell,
                  row: r,
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
            row: clampedSelectedRow,
            col: clampedSelectedCol,
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

      final pasteTable = _pasteTableRegex.firstMatch(cmd);
      if (pasteTable != null) {
        actions.add(
          const FlowBotAction(type: FlowBotActionType.pasteTable),
        );
        continue;
      }

      final exportBundle = _exportBundleRegex.firstMatch(cmd);
      if (exportBundle != null) {
        actions.add(
          const FlowBotAction(type: FlowBotActionType.exportBundle),
        );
        continue;
      }

      final quickPattern = _quickFieldPatternRegex.firstMatch(cmd);
      if (quickPattern != null) {
        final start = int.tryParse(quickPattern.group(1) ?? '');
        final status = (quickPattern.group(2) ?? '').trim();
        final obs = (quickPattern.group(4) ?? '').trim();

        if (start != null) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.autoId,
              start: start,
              step: 1,
              count: rows.length.clamp(1, 500),
            ),
          );
        }

        if (status.isNotEmpty) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.applyStatus,
              status: _normalizeStatus(status),
            ),
          );
        }

        actions.add(
          const FlowBotAction(
            type: FlowBotActionType.setToday,
            format: 'yyyy-mm-dd',
          ),
        );

        if (obs.isNotEmpty) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.setCell,
              row: clampedSelectedRow,
              col: clampedSelectedCol,
              value: obs,
            ),
          );
        }
        continue;
      }

      final setActive = _setActiveRegex.firstMatch(cmd);
      if (setActive != null) {
        final value = (setActive.group(1) ?? '').trim();
        if (value.isNotEmpty) {
          actions.add(
            FlowBotAction(
              type: FlowBotActionType.setCell,
              row: clampedSelectedRow,
              col: clampedSelectedCol,
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

  bool isApplyConfirmation(String raw) {
    final normalized =
    raw.trim().toLowerCase().replaceAll(RegExp(r'[.!?,;:]+$'), '');
    if (normalized.isEmpty) return false;
    return _applyConfirmationRegex.hasMatch(normalized);
  }

  bool _containsAny(String text, List<String> tokens) {
    for (final token in tokens) {
      if (text.contains(token)) return true;
    }
    return false;
  }

  List<int> _normalizeSelectedRows(
      List<int>? selectedRows, {
        required int fallbackRow,
        required int maxRows,
      }) {
    final source = (selectedRows == null || selectedRows.isEmpty)
        ? <int>[fallbackRow]
        : selectedRows;

    final normalized = source
        .map((row) => row.clamp(0, maxRows - 1))
        .toSet()
        .toList()
      ..sort();

    return normalized.isEmpty ? <int>[fallbackRow] : normalized;
  }

  List<String> _splitCommands(String raw) {
    if (raw.trim().isEmpty) return const <String>[];

    var normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    normalized = normalized
        .replaceAll(RegExp(r'\s+y luego\s+', caseSensitive: false), ';')
        .replaceAll(RegExp(r'\s+luego\s+', caseSensitive: false), ';')
        .replaceAll(RegExp(r'\s+despues\s+', caseSensitive: false), ';')
        .replaceAll(RegExp(r'\s+después\s+', caseSensitive: false), ';')
        .replaceAll(RegExp(r'\s+despues de eso\s+', caseSensitive: false), ';')
        .replaceAll(RegExp(r'\s+después de eso\s+', caseSensitive: false), ';')
        .replaceAll('\n', ';');

    return normalized
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
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

  int? _columnTokenToIndex(String token, {required int maxCols}) {
    final clean = token.trim().toUpperCase();
    if (clean.isEmpty) return null;

    final numeric = int.tryParse(clean);
    if (numeric != null) {
      return _columnNumberToIndex(numeric, maxCols);
    }

    var col = 0;
    for (final code in clean.codeUnits) {
      if (code < 65 || code > 90) return null;
      col = (col * 26) + (code - 64);
    }

    final zeroBased = col - 1;
    if (zeroBased < 0 || zeroBased >= maxCols) return null;
    return zeroBased;
  }

  int? _columnNumberToIndex(int? value, int maxCols) {
    if (value == null || value <= 0) return null;
    final zeroBased = value - 1;
    if (zeroBased >= maxCols) return null;
    return zeroBased;
  }

  int? _rowNumberToIndex(int? value, int maxRows) {
    if (value == null || value <= 0) return null;
    final zeroBased = value - 1;
    if (zeroBased >= maxRows) return null;
    return zeroBased;
  }

  static final RegExp _applyConfirmationRegex = RegExp(
    r'^(?:ok|dale|listo|aplicar|aplicar cambios|aceptar|confirmar)$',
    caseSensitive: false,
  );

  static final RegExp _setByA1Regex = RegExp(
    r'^(?:poner|pon[eé]|set|escribir|escrib[ií])\s+(.+?)\s+(?:en|at)\s+([A-Za-z]+)(\d+)$',
    caseSensitive: false,
  );

  static final RegExp _setByRowColRegex = RegExp(
    r'^(?:poner|pon[eé]|set|escribir|escrib[ií])\s+(.+?)\s+(?:en\s+)?fila\s*(\d+)\s*(?:columna|col)\s*(\d+)$',
    caseSensitive: false,
  );

  static final RegExp _fillRangeRegex = RegExp(
    r'^(?:rellenar|completar|fill(?:\s+down)?)\s+(.+?)(?:\s+(?:por|x)\s*(\d+))?$',
    caseSensitive: false,
  );

  static final RegExp _setAlignRegex = RegExp(
    r'^(?:alinear|align)(?:\s+columna)?\s*([A-Za-z]+|\d+)?\s*(?:a\s*)?(izquierda|centro|centrado|derecha|left|center|right)$',
    caseSensitive: false,
  );

  static final RegExp _setWrapRegex = RegExp(
    r'^(?:wrap|ajuste|ajustar)(?:\s+columna)?\s*([A-Za-z]+|\d+)?\s*(?:a\s*)?(1|2|3)?(?:\s*lineas?|\s*líneas?)?$',
    caseSensitive: false,
  );

  static final RegExp _statusRegex = RegExp(
    r'^(?:estado|status|marcar\s+como)\s+(ok|obs|urgente|pendiente)$',
    caseSensitive: false,
  );

  static final RegExp _newRowWithValuesRegex = RegExp(
    r'^fila\s+nueva\s*:\s*(.+)$',
    caseSensitive: false,
  );

  static final RegExp _clearSelectionRegex = RegExp(
    r'^(?:limpiar|borrar)\s+(?:seleccion|selección)$',
    caseSensitive: false,
  );

  static final RegExp _clearRowRegex = RegExp(
    r'^(?:limpiar|borrar)\s+fila(?:\s+actual)?$',
    caseSensitive: false,
  );

  static final RegExp _setTodayRegex = RegExp(
    r'^(?:hoy|fecha(?:\s+hoy)?|set today)(?:\s+formato\s+([a-zA-Z0-9:/._-]+))?(?:\s+(seleccion|selección|columna(?:\s+completa)?|celda\s+activa))?$',
    caseSensitive: false,
  );

  static final RegExp _autoIdRegex = RegExp(
    r'^(?:autoid|id auto|autonumerar)(?:\s+desde\s*(\d+))?(?:\s+paso\s*(\d+))?$',
    caseSensitive: false,
  );

  static final RegExp _autonumberRegex = RegExp(
    r'^autonumerar(?:\s+progresiva)?(?:\s+desde\s*(\d+))?(?:\s+paso\s*(\d+))?$',
    caseSensitive: false,
  );

  static final RegExp _fillSeriesRegex = RegExp(
    r'^(?:rellenar\s+)?progresiva(?:\s+desde)?\s*(\d+)?(?:\s+cada\s*(\d+))?(?:\s+(?:por|x)\s*(\d+)\s*filas?)?$',
    caseSensitive: false,
  );

  static final RegExp _copyGpsRegex = RegExp(
    r'^(?:copiar\s+gps(?:\s+de\s+fila\s*(\d+))?|gps\s+fila\s*(\d+)\s+a\s+seleccion)$',
    caseSensitive: false,
  );

  static final RegExp _duplicateRowRegex = RegExp(
    r'^(?:duplicar(?:me)?\s+fila\s*(\d+)?(?:\s*(?:x|por)\s*(\d+))?)$',
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

  static final RegExp _pasteTableRegex = RegExp(
    r'^(?:pegar\s+tabla|pegar|paste\s+table)$',
    caseSensitive: false,
  );

  static final RegExp _exportBundleRegex = RegExp(
    r'^(?:exportar\s+paquete(?:\s+completo)?|exportar\s+zip|export\s+bundle)$',
    caseSensitive: false,
  );

  static final RegExp _quickFieldPatternRegex = RegExp(
    r'^progresiva\s+(\d+)\s*,?\s*estado\s+([a-zA-Z]+)\s*,?\s*fecha\s+hoy(?:\s*,?\s*(obs|observacion|observación)\s+(.+))?$',
    caseSensitive: false,
  );

  static final RegExp _setActiveRegex = RegExp(
    r'^(?:poner|pon[eé]|set|escribir|escrib[ií])\s+(.+)$',
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
        warning: 'Comando vacío.',
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
      final raw = await _channel.invokeMethod<Object?>(
        'parse',
        <String, Object?>{
          'modelPath': model,
          'command': command,
          'selectedRow': selectedRow,
          'selectedCol': selectedCol,
          'selectedRows': selectedRows,
        },
      ).timeout(timeout);

      if (raw == null) {
        return const FlowBotParseResult(
          actions: <FlowBotAction>[],
          engine: 'local_llm',
          warning: 'Local LLM no devolvió respuesta.',
        );
      }

      final decoded = _decodeLlmPayload(raw);
      if (decoded == null) {
        return const FlowBotParseResult(
          actions: <FlowBotAction>[],
          engine: 'local_llm',
          warning: 'Respuesta local inválida.',
        );
      }

      final actions = FlowBotAction.parseActionsList(
        decoded['actions'],
        maxActions: 50,
      );
      final warning = _stringOrNull(decoded['warning']);

      return FlowBotParseResult(
        actions: actions,
        engine: 'local_llm',
        warning: warning ??
            (actions.isEmpty ? 'Local LLM sin acciones aplicables.' : null),
      );
    } on MissingPluginException {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'local_llm',
        warning: 'Runtime local LLM no instalado; usar motor offline.',
      );
    } on TimeoutException {
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'local_llm',
        warning: 'Local LLM timeout; usar motor offline.',
      );
    } catch (e) {
      debugPrint('FlowBotLocalLlmEngine.parse error: $e');
      return const FlowBotParseResult(
        actions: <FlowBotAction>[],
        engine: 'local_llm',
        warning: 'Local LLM error; usar motor offline.',
      );
    }
  }

  Map<String, Object?>? _decodeLlmPayload(Object raw) {
    Object? decoded = raw;

    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) return null;
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        return null;
      }
    }

    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  String? _stringOrNull(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}