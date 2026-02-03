import 'package:flutter_test/flutter_test.dart';
import 'package:bitacora_web/services/expression_eval.dart';

void main() {
  group('evalExpression', () {
    test('handles basic precedence and parentheses', () {
      expect(evalExpression('1+2*3'), 7);
      expect(evalExpression('(2+3)*4'), 20);
    });

    test('handles unary sign', () {
      expect(evalExpression('-2+3'), 1);
      expect(evalExpression('+-2'), -2);
    });

    test('accepts decimal comma and symbols', () {
      expect(evalExpression('1,5 + 2,5'), 4);
      expect(evalExpression('2x3'), 6);
      expect(evalExpression('10 \u00F7 2'), 5);
      expect(evalExpression('50%'), closeTo(0.5, 0.000001));
      expect(evalExpression('200+10%'), closeTo(200.1, 0.000001));
    });

    test('returns null on invalid input', () {
      expect(evalExpression(''), isNull);
      expect(evalExpression('abc'), isNull);
      expect(evalExpression('1+'), isNull);
    });
  });
}
