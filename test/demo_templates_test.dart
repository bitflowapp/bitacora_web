import 'package:bitacora_web/services/demo_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo templates cover technical B2B workflows', () {
    const expectedSlugs = <String>{
      'proteccion-catodica',
      'puesta-a-tierra',
      'relevamiento-evidencias',
      'campo',
      'control-operativo',
    };

    final slugs = kDemoTemplateSpecs.map((spec) => spec.slug).toSet();
    expect(slugs.containsAll(expectedSlugs), isTrue);
  });

  test('demo template rows match header width', () {
    for (final spec in kDemoTemplateSpecs) {
      expect(spec.headers, isNotEmpty, reason: spec.slug);
      expect(spec.rows, isNotEmpty, reason: spec.slug);
      for (final row in spec.rows) {
        expect(row.length, spec.headers.length, reason: spec.slug);
      }
    }
  });

  test('demo template aliases resolve to commercial templates', () {
    expect(resolveDemoTemplateFromSlug('pc')?.slug, 'proteccion-catodica');
    expect(resolveDemoTemplateFromSlug('pat')?.slug, 'puesta-a-tierra');
    expect(resolveDemoTemplateFromSlug('evidencias')?.slug,
        'relevamiento-evidencias');
    expect(resolveDemoTemplateFromSlug('operativo')?.slug, 'control-operativo');
  });
}
