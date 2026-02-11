import 'package:bitacora_web/features/editor/validation/validation_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('required and number min/max validation', () {
    const rule = ColumnValidationRule(
      type: 'number',
      required: true,
      numberMin: 10,
      numberMax: 20,
    );

    expect(rule.validate(''), 'Campo requerido');
    expect(rule.validate('abc'), 'Numero invalido');
    expect(rule.validate('9'), contains('minimo'));
    expect(rule.validate('21'), contains('maximo'));
    expect(rule.validate('15'), isNull);
  });

  test('date enum and regex validation', () {
    const dateRule = ColumnValidationRule(type: 'date');
    const enumRule = ColumnValidationRule(
      type: 'enum',
      enumValues: <String>['OK', 'Obs'],
    );
    const regexRule = ColumnValidationRule(
      type: 'text',
      regexPattern: r'^[A-Z]{3}-\d{4}$',
    );

    expect(dateRule.validate('31/12/2026'), isNull);
    expect(dateRule.validate('2026-02-11 10:30'), isNull);
    expect(dateRule.validate('31-31-2026'), contains('Fecha invalida'));

    expect(enumRule.validate('OK'), isNull);
    expect(enumRule.validate('obs'), isNull);
    expect(enumRule.validate('X'), contains('Valor no permitido'));

    expect(regexRule.validate('ABC-1234'), isNull);
    expect(regexRule.validate('abc-1234'), contains('Formato invalido'));
  });
}
