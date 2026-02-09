// lib/services/expression_eval.dart
//
// Small expression evaluator for the "Calc" action.
// - Supports + - * / and parentheses.
// - Accepts decimal comma and common multiply/divide symbols.

double? evalExpression(String raw) {
  final src = _normalizeExpression(raw);
  if (src.isEmpty) return null;

  final output = <double>[];
  final ops = <String>[];
  int i = 0;
  bool expectUnary = true;
  bool invalid = false;

  int precedence(String op) {
    if (op == '+' || op == '-') return 1;
    if (op == '*' || op == '/') return 2;
    return 0;
  }

  void applyOp() {
    if (ops.isEmpty) return;
    final op = ops.removeLast();
    if (output.length < 2) {
      invalid = true;
      return;
    }
    final b = output.removeLast();
    final a = output.removeLast();
    switch (op) {
      case '+':
        output.add(a + b);
      case '-':
        output.add(a - b);
      case '*':
        output.add(a * b);
      case '/':
        output.add(b == 0 ? a : a / b);
    }
  }

  while (i < src.length) {
    final ch = src[i];
    if (_isWhitespace(ch)) {
      i++;
      continue;
    }
    if (ch == '(') {
      ops.add(ch);
      i++;
      expectUnary = true;
      continue;
    }
    if (ch == ')') {
      while (ops.isNotEmpty && ops.last != '(') {
        applyOp();
      }
      if (ops.isNotEmpty && ops.last == '(') {
        ops.removeLast();
      }
      i++;
      expectUnary = false;
      continue;
    }
    if ('+-*/'.contains(ch)) {
      if (ch == '+' && expectUnary) {
        i++;
        continue;
      }
      if (ch == '-' && expectUnary) {
        int j = i + 1;
        while (j < src.length && _isWhitespace(src[j])) {
          j++;
        }
        final numBuf = StringBuffer('-');
        int k = j;
        while (k < src.length && _isNumberChar(src[k])) {
          numBuf.write(src[k]);
          k++;
        }
        var v = double.tryParse(numBuf.toString());
        if (v == null) return null;
        if (k < src.length && src[k] == '%') {
          v = v / 100;
          k++;
        }
        output.add(v);
        i = k;
        expectUnary = false;
        continue;
      }
      while (ops.isNotEmpty && precedence(ops.last) >= precedence(ch)) {
        applyOp();
        if (invalid) return null;
      }
      ops.add(ch);
      i++;
      expectUnary = true;
      continue;
    }

    final buf = StringBuffer();
    while (i < src.length && _isNumberChar(src[i])) {
      buf.write(src[i]);
      i++;
    }
    if (buf.isEmpty) return null;
    var v = double.tryParse(buf.toString());
    if (v == null) return null;
    if (i < src.length && src[i] == '%') {
      v = v / 100;
      i++;
    }
    output.add(v);
    expectUnary = false;
  }

  while (ops.isNotEmpty) {
    if (ops.last == '(') {
      ops.removeLast();
      continue;
    }
    applyOp();
    if (invalid) return null;
  }
  if (output.isEmpty) return null;
  return output.last;
}

String _normalizeExpression(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return '';

  s = s
      .replaceAll('\u00D7', '*')
      .replaceAll('\u00F7', '/')
      .replaceAll('x', '*')
      .replaceAll('X', '*')
      .replaceAll(',', '.');
  return s;
}

bool _isWhitespace(String ch) => ch == ' ' || ch == '\t' || ch == '\n';

bool _isNumberChar(String ch) => RegExp(r'[0-9\.]').hasMatch(ch);
