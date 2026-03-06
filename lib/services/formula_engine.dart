import 'dart:math' as math;

typedef FormulaCellValueResolver = String Function(FormulaCellAddress cell);
typedef FormulaCellAvailabilityResolver = bool Function(
  FormulaCellAddress cell,
);

class FormulaCellAddress {
  const FormulaCellAddress({
    required this.row,
    required this.col,
  });

  final int row;
  final int col;

  String get a1 => '${_colToLetters(col)}${row + 1}';

  static FormulaCellAddress? fromA1(String raw) {
    final match = RegExp(r'^([A-Za-z]+)([1-9][0-9]*)$').firstMatch(raw.trim());
    if (match == null) return null;
    final colLetters = match.group(1)!;
    final rowValue = int.tryParse(match.group(2) ?? '');
    if (rowValue == null || rowValue <= 0) return null;
    final col = _lettersToCol(colLetters);
    if (col < 0) return null;
    return FormulaCellAddress(row: rowValue - 1, col: col);
  }

  static int _lettersToCol(String letters) {
    var out = 0;
    final upper = letters.toUpperCase();
    for (final unit in upper.codeUnits) {
      final offset = unit - 64;
      if (offset < 1 || offset > 26) return -1;
      out = (out * 26) + offset;
    }
    return out - 1;
  }

  static String _colToLetters(int col) {
    if (col < 0) return 'A';
    var n = col;
    final out = StringBuffer();
    while (n >= 0) {
      out.writeCharCode(65 + (n % 26));
      n = (n ~/ 26) - 1;
    }
    return out.toString().split('').reversed.join();
  }

  @override
  bool operator ==(Object other) =>
      other is FormulaCellAddress && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

class FormulaErrors {
  static const String ref = '#REF';
  static const String div0 = '#DIV/0';
  static const String value = '#VALUE';
  static const String cycle = '#CYCLE';
  static const String pro = '#PRO!';

  static const Set<String> all = <String>{
    ref,
    div0,
    value,
    cycle,
    pro,
  };

  static bool isKnown(String raw) => all.contains(raw.trim().toUpperCase());
}

class FormulaFunctionDefinition {
  const FormulaFunctionDefinition({
    required this.name,
    required this.minArgs,
    this.maxArgs,
  });

  final String name;
  final int minArgs;
  final int? maxArgs;

  bool acceptsArgCount(int count) {
    if (count < minArgs) return false;
    final max = maxArgs;
    if (max != null && count > max) return false;
    return true;
  }
}

class FormulaAutocompleteSuggestion {
  const FormulaAutocompleteSuggestion({
    required this.name,
    required this.insertText,
    required this.replaceStart,
    required this.replaceEnd,
    required this.selectionOffset,
  });

  final String name;
  final String insertText;
  final int replaceStart;
  final int replaceEnd;
  final int selectionOffset;

  String apply(String raw) =>
      raw.replaceRange(replaceStart, replaceEnd, insertText);
}

class FormulaEvaluationResult {
  const FormulaEvaluationResult({
    required this.value,
    required this.references,
    this.error,
  });

  final dynamic value;
  final Set<FormulaCellAddress> references;
  final String? error;

  bool get hasError => (error ?? '').isNotEmpty;
}

class ParsedFormula {
  const ParsedFormula._({
    required this.source,
    required _Expr root,
    required this.references,
  }) : _root = root;

  final String source;
  final _Expr _root;
  final Set<FormulaCellAddress> references;
}

class FormulaEngine {
  const FormulaEngine();

  static const String errorValue = FormulaErrors.value;

  static final List<FormulaFunctionDefinition> _functionRegistry =
      List<FormulaFunctionDefinition>.unmodifiable(
    const <FormulaFunctionDefinition>[
      FormulaFunctionDefinition(name: 'SUM', minArgs: 1),
      FormulaFunctionDefinition(name: 'AVERAGE', minArgs: 1),
      FormulaFunctionDefinition(name: 'MIN', minArgs: 1),
      FormulaFunctionDefinition(name: 'MAX', minArgs: 1),
      FormulaFunctionDefinition(name: 'COUNT', minArgs: 1),
      FormulaFunctionDefinition(name: 'DATE', minArgs: 3, maxArgs: 3),
      FormulaFunctionDefinition(name: 'NOW', minArgs: 0, maxArgs: 0),
      FormulaFunctionDefinition(name: 'TODAY', minArgs: 0, maxArgs: 0),
      FormulaFunctionDefinition(name: 'ROUND', minArgs: 1, maxArgs: 2),
      FormulaFunctionDefinition(name: 'IF', minArgs: 3, maxArgs: 3),
      FormulaFunctionDefinition(name: 'VLOOKUP', minArgs: 3, maxArgs: 4),
      FormulaFunctionDefinition(name: 'HLOOKUP', minArgs: 3, maxArgs: 4),
      FormulaFunctionDefinition(name: 'INDEX', minArgs: 2, maxArgs: 3),
      FormulaFunctionDefinition(name: 'MATCH', minArgs: 2, maxArgs: 3),
      FormulaFunctionDefinition(name: 'FILTER', minArgs: 2, maxArgs: 3),
      FormulaFunctionDefinition(name: 'CONCAT', minArgs: 1),
      FormulaFunctionDefinition(name: 'LEN', minArgs: 1, maxArgs: 1),
      FormulaFunctionDefinition(name: 'LOWER', minArgs: 1, maxArgs: 1),
      FormulaFunctionDefinition(name: 'UPPER', minArgs: 1, maxArgs: 1),
      FormulaFunctionDefinition(name: 'ABS', minArgs: 1, maxArgs: 1),
      FormulaFunctionDefinition(name: 'POWER', minArgs: 2, maxArgs: 2),
      FormulaFunctionDefinition(name: 'YEAR', minArgs: 1, maxArgs: 1),
      FormulaFunctionDefinition(name: 'MONTH', minArgs: 1, maxArgs: 1),
      FormulaFunctionDefinition(name: 'DAY', minArgs: 1, maxArgs: 1),
    ],
  );

  static final Map<String, FormulaFunctionDefinition> _functionByName =
      <String, FormulaFunctionDefinition>{
    for (final function in _functionRegistry) function.name: function,
  };

  List<FormulaFunctionDefinition> get registeredFunctions => _functionRegistry;

  List<String> get registeredFunctionNames => <String>[
        for (final function in _functionRegistry) function.name,
      ];

  static bool isFormula(String raw) {
    final trimmed = raw.trimLeft();
    return trimmed.startsWith('=');
  }

  static bool isErrorValue(String raw) => FormulaErrors.isKnown(raw);

  List<FormulaAutocompleteSuggestion> suggestFunctions(
    String raw, {
    int limit = 6,
  }) {
    final token = _extractAutocompleteToken(raw);
    if (token == null) return const <FormulaAutocompleteSuggestion>[];
    final prefix = token.token.toUpperCase();
    if (prefix.isEmpty) return const <FormulaAutocompleteSuggestion>[];

    final matches = _functionRegistry.where((function) {
      final name = function.name;
      return name.startsWith(prefix) && name != prefix;
    }).take(limit);

    return <FormulaAutocompleteSuggestion>[
      for (final function in matches)
        FormulaAutocompleteSuggestion(
          name: function.name,
          insertText: '${function.name}()',
          replaceStart: token.start,
          replaceEnd: token.end,
          selectionOffset: function.minArgs == 0
              ? token.start + function.name.length + 2
              : token.start + function.name.length + 1,
        ),
    ];
  }

  ParsedFormula? tryParse(String raw) {
    final src = _normalizeFormulaSource(raw);
    if (src == null) return null;
    try {
      final tokens = _Lexer(src).tokenize();
      final root = _Parser(tokens).parse();
      final refs = _ReferenceCollector.collect(root);
      return ParsedFormula._(
        source: src,
        root: root,
        references: refs,
      );
    } catch (_) {
      return null;
    }
  }

  FormulaEvaluationResult evaluate(
    String raw, {
    required FormulaCellValueResolver readCell,
    FormulaCellAvailabilityResolver? isCellAvailable,
    DateTime? now,
  }) {
    final parsed = tryParse(raw);
    if (parsed == null) {
      return const FormulaEvaluationResult(
        value: null,
        references: <FormulaCellAddress>{},
        error: FormulaErrors.value,
      );
    }
    return evaluateParsed(
      parsed,
      readCell: readCell,
      isCellAvailable: isCellAvailable,
      now: now,
    );
  }

  FormulaEvaluationResult evaluateParsed(
    ParsedFormula parsed, {
    required FormulaCellValueResolver readCell,
    FormulaCellAvailabilityResolver? isCellAvailable,
    DateTime? now,
  }) {
    try {
      final evaluator = _Evaluator(
        readCell: readCell,
        isCellAvailable: isCellAvailable,
        now: now ?? DateTime.now(),
        functions: _functionByName,
      );
      final value = evaluator.eval(parsed._root);
      if (evaluator.error != null) {
        return FormulaEvaluationResult(
          value: null,
          references: parsed.references,
          error: evaluator.error,
        );
      }
      return FormulaEvaluationResult(
        value: value,
        references: parsed.references,
      );
    } catch (_) {
      return FormulaEvaluationResult(
        value: null,
        references: parsed.references,
        error: FormulaErrors.value,
      );
    }
  }

  String formatValue(dynamic value) {
    if (value == null) return '';
    if (value is _FormulaErrorValue) return value.code;
    if (value is _RangeValue) {
      if (value.values.isEmpty) return '';
      if (value.values.length == 1) return formatValue(value.values.first);
      return value.values.map(formatValue).join(', ');
    }
    if (value is String) return value;
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    if (value is DateTime) {
      final y = value.year.toString().padLeft(4, '0');
      final m = value.month.toString().padLeft(2, '0');
      final d = value.day.toString().padLeft(2, '0');
      final hh = value.hour.toString().padLeft(2, '0');
      final mm = value.minute.toString().padLeft(2, '0');
      final ss = value.second.toString().padLeft(2, '0');
      final hasTime = value.hour != 0 || value.minute != 0 || value.second != 0;
      return hasTime ? '$y-$m-$d $hh:$mm:$ss' : '$y-$m-$d';
    }
    if (value is num) {
      if (value.isNaN || value.isInfinite) return errorValue;
      if (value is int) return value.toString();
      final rounded = value.roundToDouble();
      if ((value - rounded).abs() < 0.0000000001) {
        return rounded.toInt().toString();
      }
      final fixed = value.toStringAsFixed(10);
      return fixed
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return value.toString();
  }

  _AutocompleteToken? _extractAutocompleteToken(String raw) {
    final trimmedLeft = raw.trimLeft();
    if (!trimmedLeft.startsWith('=')) return null;

    var end = raw.length;
    while (end > 0 && _isWhitespace(raw[end - 1])) {
      end--;
    }
    if (end <= 0) return null;

    var start = end;
    while (start > 0 && _isIdentifierPart(raw[start - 1])) {
      start--;
    }
    if (start == end) return null;

    final token = raw.substring(start, end);
    if (token.isEmpty || !_isIdentifierStart(token[0])) return null;

    final prefix = raw.substring(0, start).trimRight();
    if (prefix.isEmpty) return null;
    final previous = prefix[prefix.length - 1];
    const validPrevious = <String>{
      '=',
      '(',
      ',',
      ';',
      '+',
      '-',
      '*',
      '/',
      '<',
      '>',
    };
    if (!validPrevious.contains(previous)) return null;

    return _AutocompleteToken(
      token: token,
      start: start,
      end: end,
    );
  }

  String? _normalizeFormulaSource(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || !isFormula(trimmed)) return null;
    final src = trimmed.startsWith('=') ? trimmed.substring(1).trim() : trimmed;
    if (src.isEmpty) return null;
    return src;
  }
}

class _AutocompleteToken {
  const _AutocompleteToken({
    required this.token,
    required this.start,
    required this.end,
  });

  final String token;
  final int start;
  final int end;
}

bool _isWhitespace(String ch) => ch == ' ' || ch == '\t' || ch == '\n';
bool _isIdentifierStart(String ch) => RegExp(r'[A-Za-z_]').hasMatch(ch);
bool _isIdentifierPart(String ch) => RegExp(r'[A-Za-z0-9_]').hasMatch(ch);

enum _TokenType {
  number,
  string,
  identifier,
  plus,
  minus,
  multiply,
  divide,
  lParen,
  rParen,
  comma,
  semicolon,
  colon,
  gt,
  gte,
  lt,
  lte,
  eq,
  neq,
  eof,
}

class _Token {
  const _Token(this.type, this.lexeme);

  final _TokenType type;
  final String lexeme;
}

class _Lexer {
  _Lexer(this.source);

  final String source;
  int _i = 0;

  List<_Token> tokenize() {
    final tokens = <_Token>[];
    while (_i < source.length) {
      final ch = source[_i];
      if (_isWhitespace(ch)) {
        _i++;
        continue;
      }
      if (ch == '"') {
        tokens.add(_readString());
        continue;
      }
      if (_isDigit(ch) || ch == '.') {
        tokens.add(_readNumber());
        continue;
      }
      if (_isIdentifierStart(ch)) {
        tokens.add(_readIdentifier());
        continue;
      }

      switch (ch) {
        case '+':
          tokens.add(const _Token(_TokenType.plus, '+'));
          _i++;
          continue;
        case '-':
          tokens.add(const _Token(_TokenType.minus, '-'));
          _i++;
          continue;
        case '*':
          tokens.add(const _Token(_TokenType.multiply, '*'));
          _i++;
          continue;
        case '/':
          tokens.add(const _Token(_TokenType.divide, '/'));
          _i++;
          continue;
        case '(':
          tokens.add(const _Token(_TokenType.lParen, '('));
          _i++;
          continue;
        case ')':
          tokens.add(const _Token(_TokenType.rParen, ')'));
          _i++;
          continue;
        case ',':
          tokens.add(const _Token(_TokenType.comma, ','));
          _i++;
          continue;
        case ';':
          tokens.add(const _Token(_TokenType.semicolon, ';'));
          _i++;
          continue;
        case ':':
          tokens.add(const _Token(_TokenType.colon, ':'));
          _i++;
          continue;
        case '>':
          if (_peek() == '=') {
            tokens.add(const _Token(_TokenType.gte, '>='));
            _i += 2;
          } else {
            tokens.add(const _Token(_TokenType.gt, '>'));
            _i++;
          }
          continue;
        case '<':
          if (_peek() == '=') {
            tokens.add(const _Token(_TokenType.lte, '<='));
            _i += 2;
          } else if (_peek() == '>') {
            tokens.add(const _Token(_TokenType.neq, '<>'));
            _i += 2;
          } else {
            tokens.add(const _Token(_TokenType.lt, '<'));
            _i++;
          }
          continue;
        case '=':
          tokens.add(const _Token(_TokenType.eq, '='));
          _i++;
          continue;
        default:
          throw _FormulaException('Unexpected character "$ch"');
      }
    }
    tokens.add(const _Token(_TokenType.eof, ''));
    return tokens;
  }

  _Token _readString() {
    _i++;
    final out = StringBuffer();
    while (_i < source.length) {
      final ch = source[_i];
      if (ch == '"') {
        if (_peek() == '"') {
          out.write('"');
          _i += 2;
          continue;
        }
        _i++;
        return _Token(_TokenType.string, out.toString());
      }
      out.write(ch);
      _i++;
    }
    throw _FormulaException('Unterminated string literal');
  }

  _Token _readNumber() {
    final start = _i;
    var seenDot = false;
    while (_i < source.length) {
      final ch = source[_i];
      if (_isDigit(ch)) {
        _i++;
        continue;
      }
      if (ch == '.' || ch == ',') {
        final next = (_i + 1 < source.length) ? source[_i + 1] : '';
        if (!_isDigit(next)) break;
        if (seenDot) break;
        seenDot = true;
        _i++;
        continue;
      }
      break;
    }
    return _Token(_TokenType.number, source.substring(start, _i));
  }

  _Token _readIdentifier() {
    final start = _i;
    _i++;
    while (_i < source.length) {
      final ch = source[_i];
      if (_isIdentifierPart(ch)) {
        _i++;
        continue;
      }
      break;
    }
    return _Token(_TokenType.identifier, source.substring(start, _i));
  }

  String _peek() => (_i + 1 < source.length) ? source[_i + 1] : '';
  bool _isDigit(String ch) => RegExp(r'[0-9]').hasMatch(ch);
}

abstract class _Expr {
  const _Expr();
}

class _NumberExpr extends _Expr {
  const _NumberExpr(this.value);
  final double value;
}

class _StringExpr extends _Expr {
  const _StringExpr(this.value);
  final String value;
}

class _CellExpr extends _Expr {
  const _CellExpr(this.address);
  final FormulaCellAddress address;
}

class _RangeExpr extends _Expr {
  const _RangeExpr({
    required this.start,
    required this.end,
  });

  final FormulaCellAddress start;
  final FormulaCellAddress end;
}

class _UnaryExpr extends _Expr {
  const _UnaryExpr({
    required this.op,
    required this.value,
  });

  final _TokenType op;
  final _Expr value;
}

class _BinaryExpr extends _Expr {
  const _BinaryExpr({
    required this.left,
    required this.op,
    required this.right,
  });

  final _Expr left;
  final _TokenType op;
  final _Expr right;
}

class _FunctionExpr extends _Expr {
  const _FunctionExpr({
    required this.name,
    required this.args,
  });

  final String name;
  final List<_Expr> args;
}

class _Parser {
  _Parser(this.tokens);

  final List<_Token> tokens;
  int _i = 0;

  _Expr parse() {
    final expr = _parseComparison();
    _expect(_TokenType.eof);
    return expr;
  }

  _Expr _parseComparison() {
    var expr = _parseAdditive();
    while (true) {
      final op = _matchAny(<_TokenType>[
        _TokenType.gt,
        _TokenType.gte,
        _TokenType.lt,
        _TokenType.lte,
        _TokenType.eq,
        _TokenType.neq,
      ]);
      if (op == null) break;
      final right = _parseAdditive();
      expr = _BinaryExpr(left: expr, op: op.type, right: right);
    }
    return expr;
  }

  _Expr _parseAdditive() {
    var expr = _parseMultiplicative();
    while (true) {
      final op = _matchAny(<_TokenType>[_TokenType.plus, _TokenType.minus]);
      if (op == null) break;
      final right = _parseMultiplicative();
      expr = _BinaryExpr(left: expr, op: op.type, right: right);
    }
    return expr;
  }

  _Expr _parseMultiplicative() {
    var expr = _parseUnary();
    while (true) {
      final op =
          _matchAny(<_TokenType>[_TokenType.multiply, _TokenType.divide]);
      if (op == null) break;
      final right = _parseUnary();
      expr = _BinaryExpr(left: expr, op: op.type, right: right);
    }
    return expr;
  }

  _Expr _parseUnary() {
    final op = _matchAny(<_TokenType>[_TokenType.plus, _TokenType.minus]);
    if (op != null) {
      return _UnaryExpr(op: op.type, value: _parseUnary());
    }
    return _parsePrimary();
  }

  _Expr _parsePrimary() {
    final token = _peek();
    switch (token.type) {
      case _TokenType.number:
        _advance();
        final parsed = double.tryParse(token.lexeme.replaceAll(',', '.'));
        if (parsed == null) {
          throw _FormulaException('Invalid number "${token.lexeme}"');
        }
        return _NumberExpr(parsed);
      case _TokenType.string:
        _advance();
        return _StringExpr(token.lexeme);
      case _TokenType.identifier:
        _advance();
        final identifier = token.lexeme;
        if (_match(_TokenType.lParen)) {
          final args = <_Expr>[];
          if (!_check(_TokenType.rParen)) {
            do {
              args.add(_parseComparison());
            } while (_matchAny(<_TokenType>[
                  _TokenType.comma,
                  _TokenType.semicolon,
                ]) !=
                null);
          }
          _expect(_TokenType.rParen);
          return _FunctionExpr(name: identifier, args: args);
        }

        final cell = FormulaCellAddress.fromA1(identifier);
        if (cell == null) {
          throw _FormulaException('Unknown identifier "$identifier"');
        }

        if (_match(_TokenType.colon)) {
          final second = _expect(_TokenType.identifier);
          final end = FormulaCellAddress.fromA1(second.lexeme);
          if (end == null) {
            throw _FormulaException('Invalid range end "${second.lexeme}"');
          }
          return _RangeExpr(start: cell, end: end);
        }
        return _CellExpr(cell);
      case _TokenType.lParen:
        _advance();
        final expr = _parseComparison();
        _expect(_TokenType.rParen);
        return expr;
      default:
        throw _FormulaException('Unexpected token "${token.lexeme}"');
    }
  }

  _Token _expect(_TokenType type) {
    final token = _peek();
    if (token.type != type) {
      throw _FormulaException(
        'Expected ${type.name} but found ${token.type.name}',
      );
    }
    _i++;
    return token;
  }

  bool _match(_TokenType type) {
    if (_peek().type != type) return false;
    _i++;
    return true;
  }

  _Token? _matchAny(List<_TokenType> types) {
    final token = _peek();
    for (final type in types) {
      if (token.type == type) {
        _i++;
        return token;
      }
    }
    return null;
  }

  bool _check(_TokenType type) => _peek().type == type;
  _Token _peek() => tokens[_i];
  void _advance() => _i++;
}

class _ReferenceCollector {
  static const int _maxRangeCells = 100000;

  static Set<FormulaCellAddress> collect(_Expr expr) {
    final out = <FormulaCellAddress>{};
    _collectInto(expr, out);
    return out;
  }

  static void _collectInto(_Expr expr, Set<FormulaCellAddress> out) {
    switch (expr) {
      case _CellExpr():
        out.add(expr.address);
      case _RangeExpr():
        out.addAll(_expandRange(expr.start, expr.end, limit: _maxRangeCells));
      case _UnaryExpr():
        _collectInto(expr.value, out);
      case _BinaryExpr():
        _collectInto(expr.left, out);
        _collectInto(expr.right, out);
      case _FunctionExpr():
        for (final arg in expr.args) {
          _collectInto(arg, out);
        }
      case _NumberExpr():
      case _StringExpr():
        break;
    }
  }

  static List<FormulaCellAddress> _expandRange(
    FormulaCellAddress start,
    FormulaCellAddress end, {
    required int limit,
  }) {
    final top = math.min(start.row, end.row);
    final bottom = math.max(start.row, end.row);
    final left = math.min(start.col, end.col);
    final right = math.max(start.col, end.col);
    final out = <FormulaCellAddress>[];
    for (int r = top; r <= bottom; r++) {
      for (int c = left; c <= right; c++) {
        if (out.length >= limit) return out;
        out.add(FormulaCellAddress(row: r, col: c));
      }
    }
    return out;
  }
}

class _RangeValue {
  const _RangeValue({
    required this.values,
    required this.rowCount,
    required this.colCount,
  });

  final List<dynamic> values;
  final int rowCount;
  final int colCount;

  bool get isEmpty => values.isEmpty;
  int get length => values.length;

  dynamic valueAt(int row, int col) => values[(row * colCount) + col];

  List<dynamic> rowAt(int row) {
    final out = <dynamic>[];
    for (int col = 0; col < colCount; col++) {
      out.add(valueAt(row, col));
    }
    return out;
  }

  List<dynamic> columnAt(int col) {
    final out = <dynamic>[];
    for (int row = 0; row < rowCount; row++) {
      out.add(valueAt(row, col));
    }
    return out;
  }
}

class _FormulaErrorValue {
  const _FormulaErrorValue(this.code);
  final String code;
}

class _Evaluator {
  _Evaluator({
    required this.readCell,
    required this.now,
    required this.functions,
    this.isCellAvailable,
  });

  final FormulaCellValueResolver readCell;
  final FormulaCellAvailabilityResolver? isCellAvailable;
  final DateTime now;
  final Map<String, FormulaFunctionDefinition> functions;
  String? error;

  dynamic eval(_Expr expr) {
    final value = _eval(expr);
    if (value is _FormulaErrorValue) {
      error = value.code;
      return null;
    }
    return value;
  }

  dynamic _eval(_Expr expr) {
    switch (expr) {
      case _NumberExpr():
        return expr.value;
      case _StringExpr():
        return expr.value;
      case _CellExpr():
        if (isCellAvailable != null && !isCellAvailable!(expr.address)) {
          return _error(FormulaErrors.ref);
        }
        return _coerceCellText(readCell(expr.address));
      case _RangeExpr():
        return _evalRange(expr.start, expr.end);
      case _UnaryExpr():
        final value = _eval(expr.value);
        if (value is _FormulaErrorValue) return value;
        final number = _toNumber(value);
        if (number == null) return _error(FormulaErrors.value);
        if (expr.op == _TokenType.minus) return -number;
        return number;
      case _BinaryExpr():
        return _evalBinary(expr);
      case _FunctionExpr():
        return _evalFunction(expr);
    }
  }

  dynamic _evalRange(FormulaCellAddress start, FormulaCellAddress end) {
    final top = math.min(start.row, end.row);
    final bottom = math.max(start.row, end.row);
    final left = math.min(start.col, end.col);
    final right = math.max(start.col, end.col);
    final out = <dynamic>[];
    for (int r = top; r <= bottom; r++) {
      for (int c = left; c <= right; c++) {
        final cell = FormulaCellAddress(row: r, col: c);
        if (isCellAvailable != null && !isCellAvailable!(cell)) {
          return _error(FormulaErrors.ref);
        }
        out.add(_coerceCellText(readCell(cell)));
      }
    }
    return _RangeValue(
      values: out,
      rowCount: (bottom - top) + 1,
      colCount: (right - left) + 1,
    );
  }

  dynamic _evalBinary(_BinaryExpr expr) {
    final left = _eval(expr.left);
    if (left is _FormulaErrorValue) return left;
    final right = _eval(expr.right);
    if (right is _FormulaErrorValue) return right;

    switch (expr.op) {
      case _TokenType.plus:
      case _TokenType.minus:
      case _TokenType.multiply:
      case _TokenType.divide:
        final a = _toNumber(left);
        final b = _toNumber(right);
        if (a == null || b == null) return _error(FormulaErrors.value);
        switch (expr.op) {
          case _TokenType.plus:
            return a + b;
          case _TokenType.minus:
            return a - b;
          case _TokenType.multiply:
            return a * b;
          case _TokenType.divide:
            if (b == 0) return _error(FormulaErrors.div0);
            return a / b;
          default:
            return _error(FormulaErrors.value);
        }
      case _TokenType.gt:
      case _TokenType.gte:
      case _TokenType.lt:
      case _TokenType.lte:
      case _TokenType.eq:
      case _TokenType.neq:
        return _compareValues(left, right, expr.op);
      default:
        return _error(FormulaErrors.value);
    }
  }

  dynamic _evalFunction(_FunctionExpr expr) {
    final name = expr.name.trim().toUpperCase();
    final definition = functions[name];
    if (definition == null) return _error(FormulaErrors.value);
    if (!definition.acceptsArgCount(expr.args.length)) {
      return _error(FormulaErrors.value);
    }

    switch (name) {
      case 'SUM':
        return _sum(expr.args);
      case 'AVERAGE':
        return _average(expr.args);
      case 'MIN':
        return _min(expr.args);
      case 'MAX':
        return _max(expr.args);
      case 'COUNT':
        return _count(expr.args);
      case 'DATE':
        return _date(expr.args);
      case 'NOW':
        return now;
      case 'TODAY':
        return DateTime(now.year, now.month, now.day);
      case 'ROUND':
        return _round(expr.args);
      case 'IF':
        return _if(expr.args);
      case 'VLOOKUP':
        return _vlookup(expr.args);
      case 'HLOOKUP':
        return _hlookup(expr.args);
      case 'INDEX':
        return _index(expr.args);
      case 'MATCH':
        return _match(expr.args);
      case 'FILTER':
        return _filter(expr.args);
      case 'CONCAT':
        return _concat(expr.args);
      case 'LEN':
        return _len(expr.args);
      case 'LOWER':
        return _lower(expr.args);
      case 'UPPER':
        return _upper(expr.args);
      case 'ABS':
        return _abs(expr.args);
      case 'POWER':
        return _power(expr.args);
      case 'YEAR':
        return _year(expr.args);
      case 'MONTH':
        return _month(expr.args);
      case 'DAY':
        return _day(expr.args);
      default:
        return _error(FormulaErrors.value);
    }
  }

  dynamic _sum(List<_Expr> args) {
    final values = _evalArgs(args);
    if (values is _FormulaErrorValue) return values;
    final nums = _collectNumbers(values);
    return nums.fold<double>(0, (prev, item) => prev + item);
  }

  dynamic _average(List<_Expr> args) {
    final values = _evalArgs(args);
    if (values is _FormulaErrorValue) return values;
    final nums = _collectNumbers(values);
    if (nums.isEmpty) return 0;
    final total = nums.fold<double>(0, (prev, item) => prev + item);
    return total / nums.length;
  }

  dynamic _min(List<_Expr> args) {
    final values = _evalArgs(args);
    if (values is _FormulaErrorValue) return values;
    final nums = _collectNumbers(values);
    if (nums.isEmpty) return 0;
    return nums.reduce(math.min);
  }

  dynamic _max(List<_Expr> args) {
    final values = _evalArgs(args);
    if (values is _FormulaErrorValue) return values;
    final nums = _collectNumbers(values);
    if (nums.isEmpty) return 0;
    return nums.reduce(math.max);
  }

  dynamic _count(List<_Expr> args) {
    final values = _evalArgs(args);
    if (values is _FormulaErrorValue) return values;
    return _collectNumbers(values).length;
  }

  dynamic _date(List<_Expr> args) {
    final values = _evalArgs(args);
    if (values is _FormulaErrorValue) return values;
    final year = _toNumber(values[0])?.round();
    final month = _toNumber(values[1])?.round();
    final day = _toNumber(values[2])?.round();
    if (year == null || month == null || day == null) {
      return _error(FormulaErrors.value);
    }
    return DateTime(year, month, day);
  }

  dynamic _round(List<_Expr> args) {
    final values = _evalArgs(args);
    if (values is _FormulaErrorValue) return values;
    final value = _toNumber(values[0]);
    if (value == null) return _error(FormulaErrors.value);
    final digits = args.length > 1 ? (_toNumber(values[1])?.round() ?? 0) : 0;
    final scale = math.pow(10, digits).toDouble();
    return (value * scale).roundToDouble() / scale;
  }

  dynamic _if(List<_Expr> args) {
    final condition = _eval(args[0]);
    if (condition is _FormulaErrorValue) return condition;
    final branch = _toBool(condition) ? args[1] : args[2];
    return _eval(branch);
  }

  dynamic _vlookup(List<_Expr> args) {
    final lookup = _eval(args[0]);
    if (lookup is _FormulaErrorValue) return lookup;
    final table = _eval(args[1]);
    if (table is _FormulaErrorValue) return table;
    final range = _asRange(table);
    if (range == null || range.colCount < 1 || range.rowCount < 1) {
      return _error(FormulaErrors.value);
    }
    final colIndex = _eval(args[2]);
    if (colIndex is _FormulaErrorValue) return colIndex;
    final column = _toNumber(colIndex)?.round();
    if (column == null || column <= 0 || column > range.colCount) {
      return _error(FormulaErrors.ref);
    }
    final approximate = args.length > 3 ? _eval(args[3]) : false;
    if (approximate is _FormulaErrorValue) return approximate;
    final rowIndex = _lookupRowIndex(
      lookup,
      range.columnAt(0),
      approximate: _toBool(approximate),
    );
    if (rowIndex < 0) return _error(FormulaErrors.value);
    return range.valueAt(rowIndex, column - 1);
  }

  dynamic _hlookup(List<_Expr> args) {
    final lookup = _eval(args[0]);
    if (lookup is _FormulaErrorValue) return lookup;
    final table = _eval(args[1]);
    if (table is _FormulaErrorValue) return table;
    final range = _asRange(table);
    if (range == null || range.colCount < 1 || range.rowCount < 1) {
      return _error(FormulaErrors.value);
    }
    final rowIndex = _eval(args[2]);
    if (rowIndex is _FormulaErrorValue) return rowIndex;
    final row = _toNumber(rowIndex)?.round();
    if (row == null || row <= 0 || row > range.rowCount) {
      return _error(FormulaErrors.ref);
    }
    final approximate = args.length > 3 ? _eval(args[3]) : false;
    if (approximate is _FormulaErrorValue) return approximate;
    final colIndex = _lookupRowIndex(
      lookup,
      range.rowAt(0),
      approximate: _toBool(approximate),
    );
    if (colIndex < 0) return _error(FormulaErrors.value);
    return range.valueAt(row - 1, colIndex);
  }

  dynamic _index(List<_Expr> args) {
    final source = _eval(args[0]);
    if (source is _FormulaErrorValue) return source;
    final range = _asRange(source);
    if (range == null) {
      final row = _eval(args[1]);
      if (row is _FormulaErrorValue) return row;
      final rowIndex = _toNumber(row)?.round() ?? 0;
      if (rowIndex != 1) return _error(FormulaErrors.ref);
      if (args.length > 2) {
        final col = _eval(args[2]);
        if (col is _FormulaErrorValue) return col;
        final colIndex = _toNumber(col)?.round() ?? 0;
        if (colIndex != 1) return _error(FormulaErrors.ref);
      }
      return source;
    }

    final rowValue = _eval(args[1]);
    if (rowValue is _FormulaErrorValue) return rowValue;
    final rowIndex = _toNumber(rowValue)?.round();
    if (rowIndex == null || rowIndex <= 0) return _error(FormulaErrors.ref);

    if (args.length == 2) {
      if (range.colCount == 1) {
        if (rowIndex > range.rowCount) return _error(FormulaErrors.ref);
        return range.valueAt(rowIndex - 1, 0);
      }
      if (range.rowCount == 1) {
        if (rowIndex > range.colCount) return _error(FormulaErrors.ref);
        return range.valueAt(0, rowIndex - 1);
      }
      if (rowIndex > range.rowCount) return _error(FormulaErrors.ref);
      return range.valueAt(rowIndex - 1, 0);
    }

    final colValue = _eval(args[2]);
    if (colValue is _FormulaErrorValue) return colValue;
    final colIndex = _toNumber(colValue)?.round();
    if (colIndex == null || colIndex <= 0) return _error(FormulaErrors.ref);
    if (rowIndex > range.rowCount || colIndex > range.colCount) {
      return _error(FormulaErrors.ref);
    }
    return range.valueAt(rowIndex - 1, colIndex - 1);
  }

  dynamic _match(List<_Expr> args) {
    final lookup = _eval(args[0]);
    if (lookup is _FormulaErrorValue) return lookup;
    final source = _eval(args[1]);
    if (source is _FormulaErrorValue) return source;
    final values = _rangeToVector(source);
    if (values == null) return _error(FormulaErrors.value);
    final mode = args.length > 2 ? _eval(args[2]) : 0;
    if (mode is _FormulaErrorValue) return mode;
    final matchType = _toNumber(mode)?.round() ?? 0;
    final index = _lookupRowIndex(
      lookup,
      values,
      approximate: matchType != 0,
      descending: matchType < 0,
    );
    if (index < 0) return _error(FormulaErrors.value);
    return index + 1;
  }

  dynamic _filter(List<_Expr> args) {
    final source = _eval(args[0]);
    if (source is _FormulaErrorValue) return source;
    final include = _eval(args[1]);
    if (include is _FormulaErrorValue) return include;
    final array = _asRange(source);
    final includeRange = _asRange(include);
    if (array == null || includeRange == null) {
      return _error(FormulaErrors.value);
    }

    if (includeRange.length == array.rowCount) {
      final keepRows = <int>[];
      for (int row = 0; row < array.rowCount; row++) {
        final marker = includeRange.values[row];
        if (marker is _FormulaErrorValue) return marker;
        if (_toBool(marker)) keepRows.add(row);
      }
      if (keepRows.isEmpty) {
        if (args.length > 2) {
          return _eval(args[2]);
        }
        return '';
      }
      final out = <dynamic>[];
      for (final row in keepRows) {
        out.addAll(array.rowAt(row));
      }
      return _RangeValue(
        values: out,
        rowCount: keepRows.length,
        colCount: array.colCount,
      );
    }

    if (includeRange.length == array.length) {
      final out = <dynamic>[];
      for (int i = 0; i < array.values.length; i++) {
        final marker = includeRange.values[i];
        if (marker is _FormulaErrorValue) return marker;
        if (_toBool(marker)) out.add(array.values[i]);
      }
      if (out.isEmpty) {
        if (args.length > 2) {
          return _eval(args[2]);
        }
        return '';
      }
      return _RangeValue(
        values: out,
        rowCount: out.length,
        colCount: 1,
      );
    }

    return _error(FormulaErrors.value);
  }

  dynamic _concat(List<_Expr> args) {
    final values = _evalArgs(args);
    if (values is _FormulaErrorValue) return values;
    final out = StringBuffer();
    for (final value in values) {
      if (value is _RangeValue) {
        for (final item in value.values) {
          if (item is _FormulaErrorValue) return item;
          out.write(_stringify(item));
        }
      } else {
        out.write(_stringify(value));
      }
    }
    return out.toString();
  }

  dynamic _len(List<_Expr> args) {
    final value = _eval(args[0]);
    if (value is _FormulaErrorValue) return value;
    final scalar = _singleValue(value);
    if (scalar is _FormulaErrorValue) return scalar;
    return _stringify(scalar).length;
  }

  dynamic _lower(List<_Expr> args) {
    final value = _eval(args[0]);
    if (value is _FormulaErrorValue) return value;
    final scalar = _singleValue(value);
    if (scalar is _FormulaErrorValue) return scalar;
    return _stringify(scalar).toLowerCase();
  }

  dynamic _upper(List<_Expr> args) {
    final value = _eval(args[0]);
    if (value is _FormulaErrorValue) return value;
    final scalar = _singleValue(value);
    if (scalar is _FormulaErrorValue) return scalar;
    return _stringify(scalar).toUpperCase();
  }

  dynamic _abs(List<_Expr> args) {
    final value = _eval(args[0]);
    if (value is _FormulaErrorValue) return value;
    final scalar = _singleValue(value);
    if (scalar is _FormulaErrorValue) return scalar;
    final number = _toNumber(scalar);
    if (number == null) return _error(FormulaErrors.value);
    return number.abs();
  }

  dynamic _power(List<_Expr> args) {
    final base = _eval(args[0]);
    if (base is _FormulaErrorValue) return base;
    final exponent = _eval(args[1]);
    if (exponent is _FormulaErrorValue) return exponent;
    final left = _singleValue(base);
    if (left is _FormulaErrorValue) return left;
    final right = _singleValue(exponent);
    if (right is _FormulaErrorValue) return right;
    final a = _toNumber(left);
    final b = _toNumber(right);
    if (a == null || b == null) return _error(FormulaErrors.value);
    return math.pow(a, b).toDouble();
  }

  dynamic _year(List<_Expr> args) {
    final date = _datePartValue(args[0]);
    if (date is _FormulaErrorValue) return date;
    if (date == null) return _error(FormulaErrors.value);
    return date.year;
  }

  dynamic _month(List<_Expr> args) {
    final date = _datePartValue(args[0]);
    if (date is _FormulaErrorValue) return date;
    if (date == null) return _error(FormulaErrors.value);
    return date.month;
  }

  dynamic _day(List<_Expr> args) {
    final date = _datePartValue(args[0]);
    if (date is _FormulaErrorValue) return date;
    if (date == null) return _error(FormulaErrors.value);
    return date.day;
  }

  dynamic _datePartValue(_Expr arg) {
    final value = _eval(arg);
    if (value is _FormulaErrorValue) return value;
    final scalar = _singleValue(value);
    if (scalar is _FormulaErrorValue) return scalar;
    return _toDateTime(scalar);
  }

  dynamic _evalArgs(List<_Expr> args) {
    final out = <dynamic>[];
    for (final arg in args) {
      final value = _eval(arg);
      if (value is _FormulaErrorValue) return value;
      out.add(value);
    }
    return out;
  }

  List<double> _collectNumbers(List<dynamic> args) {
    final out = <double>[];
    for (final arg in args) {
      if (arg is _RangeValue) {
        for (final item in arg.values) {
          if (item is _FormulaErrorValue) continue;
          final number = _toNumber(item);
          if (number != null) out.add(number);
        }
        continue;
      }
      final number = _toNumber(arg);
      if (number != null) out.add(number);
    }
    return out;
  }

  _RangeValue? _asRange(dynamic value) {
    if (value is _RangeValue) return value;
    return null;
  }

  List<dynamic>? _rangeToVector(dynamic value) {
    if (value is! _RangeValue) return <dynamic>[value];
    if (value.rowCount > 1 && value.colCount > 1) return null;
    return value.values;
  }

  dynamic _singleValue(dynamic value) {
    if (value is! _RangeValue) return value;
    if (value.values.isEmpty) return '';
    if (value.values.length > 1) return _error(FormulaErrors.value);
    return value.values.first;
  }

  int _lookupRowIndex(
    dynamic lookup,
    List<dynamic> values, {
    required bool approximate,
    bool descending = false,
  }) {
    if (!approximate) {
      for (int i = 0; i < values.length; i++) {
        final candidate = values[i];
        if (candidate is _FormulaErrorValue) continue;
        if (_valuesEqual(lookup, candidate)) return i;
      }
      return -1;
    }

    var bestIndex = -1;
    dynamic bestValue;
    for (int i = 0; i < values.length; i++) {
      final candidate = values[i];
      if (candidate is _FormulaErrorValue) continue;
      final comparison = _compareOrdering(candidate, lookup);
      if (comparison == null) continue;
      final compatible = descending ? comparison >= 0 : comparison <= 0;
      if (!compatible) continue;
      if (bestIndex < 0) {
        bestIndex = i;
        bestValue = candidate;
        continue;
      }
      final delta = _compareOrdering(candidate, bestValue);
      if (delta == null) continue;
      if (descending ? delta < 0 : delta > 0) {
        bestIndex = i;
        bestValue = candidate;
      }
    }
    return bestIndex;
  }

  dynamic _compareValues(dynamic left, dynamic right, _TokenType op) {
    if (left is _FormulaErrorValue) return left;
    if (right is _FormulaErrorValue) return right;

    final leftNumber = _toNumber(left);
    final rightNumber = _toNumber(right);
    if (leftNumber != null && rightNumber != null) {
      switch (op) {
        case _TokenType.gt:
          return leftNumber > rightNumber;
        case _TokenType.gte:
          return leftNumber >= rightNumber;
        case _TokenType.lt:
          return leftNumber < rightNumber;
        case _TokenType.lte:
          return leftNumber <= rightNumber;
        case _TokenType.eq:
          return leftNumber == rightNumber;
        case _TokenType.neq:
          return leftNumber != rightNumber;
        default:
          return _error(FormulaErrors.value);
      }
    }

    final leftDate = _toDateTime(left);
    final rightDate = _toDateTime(right);
    if (leftDate != null && rightDate != null) {
      final cmp = leftDate.compareTo(rightDate);
      switch (op) {
        case _TokenType.gt:
          return cmp > 0;
        case _TokenType.gte:
          return cmp >= 0;
        case _TokenType.lt:
          return cmp < 0;
        case _TokenType.lte:
          return cmp <= 0;
        case _TokenType.eq:
          return cmp == 0;
        case _TokenType.neq:
          return cmp != 0;
        default:
          return _error(FormulaErrors.value);
      }
    }

    final leftText = _stringify(left).toLowerCase();
    final rightText = _stringify(right).toLowerCase();
    final cmp = leftText.compareTo(rightText);
    switch (op) {
      case _TokenType.gt:
        return cmp > 0;
      case _TokenType.gte:
        return cmp >= 0;
      case _TokenType.lt:
        return cmp < 0;
      case _TokenType.lte:
        return cmp <= 0;
      case _TokenType.eq:
        return cmp == 0;
      case _TokenType.neq:
        return cmp != 0;
      default:
        return _error(FormulaErrors.value);
    }
  }

  dynamic _coerceCellText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (FormulaErrors.isKnown(trimmed)) {
      return _FormulaErrorValue(trimmed.toUpperCase());
    }
    if (trimmed.startsWith('"') &&
        trimmed.endsWith('"') &&
        trimmed.length > 1) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    if (trimmed.toLowerCase() == 'true') return true;
    if (trimmed.toLowerCase() == 'false') return false;
    final number = double.tryParse(trimmed.replaceAll(',', '.'));
    if (number != null) return number;
    final date = DateTime.tryParse(trimmed);
    if (date != null) return date;
    return trimmed;
  }

  _FormulaErrorValue _error(String code) => _FormulaErrorValue(code);

  double? _toNumber(dynamic value) {
    if (value is _FormulaErrorValue) return null;
    if (value is num) return value.toDouble();
    if (value is bool) return value ? 1 : 0;
    if (value is DateTime) return value.millisecondsSinceEpoch.toDouble();
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      if (normalized.isEmpty) return null;
      return double.tryParse(normalized);
    }
    return null;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  bool _toBool(dynamic value) {
    if (value is _FormulaErrorValue) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized.isEmpty) return false;
      if (normalized == 'false' || normalized == '0' || normalized == 'no') {
        return false;
      }
      return true;
    }
    if (value is _RangeValue) {
      if (value.values.isEmpty) return false;
      return _toBool(value.values.first);
    }
    return value != null;
  }

  bool _valuesEqual(dynamic left, dynamic right) {
    final leftNumber = _toNumber(left);
    final rightNumber = _toNumber(right);
    if (leftNumber != null && rightNumber != null) {
      return leftNumber == rightNumber;
    }

    final leftDate = _toDateTime(left);
    final rightDate = _toDateTime(right);
    if (leftDate != null && rightDate != null) {
      return leftDate.isAtSameMomentAs(rightDate);
    }

    return _stringify(left).toLowerCase() == _stringify(right).toLowerCase();
  }

  int? _compareOrdering(dynamic left, dynamic right) {
    final leftNumber = _toNumber(left);
    final rightNumber = _toNumber(right);
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }

    final leftDate = _toDateTime(left);
    final rightDate = _toDateTime(right);
    if (leftDate != null && rightDate != null) {
      return leftDate.compareTo(rightDate);
    }

    return _stringify(left).toLowerCase().compareTo(
          _stringify(right).toLowerCase(),
        );
  }

  String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is _FormulaErrorValue) return value.code;
    if (value is _RangeValue) {
      return value.values.map(_stringify).join(', ');
    }
    if (value is DateTime) {
      final y = value.year.toString().padLeft(4, '0');
      final m = value.month.toString().padLeft(2, '0');
      final d = value.day.toString().padLeft(2, '0');
      final hh = value.hour.toString().padLeft(2, '0');
      final mm = value.minute.toString().padLeft(2, '0');
      final ss = value.second.toString().padLeft(2, '0');
      final hasTime = value.hour != 0 || value.minute != 0 || value.second != 0;
      return hasTime ? '$y-$m-$d $hh:$mm:$ss' : '$y-$m-$d';
    }
    if (value is bool) return value ? 'TRUE' : 'FALSE';
    if (value is num) {
      final rounded = value.roundToDouble();
      if ((value - rounded).abs() < 0.0000000001) {
        return rounded.toInt().toString();
      }
      final fixed = value.toStringAsFixed(10);
      return fixed
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
    }
    return value.toString();
  }
}

class _FormulaException implements Exception {
  const _FormulaException(this.message);
  final String message;

  @override
  String toString() => 'FormulaException: $message';
}
