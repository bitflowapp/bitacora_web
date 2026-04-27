import 'package:bitacora_web/utils/location_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Evidence GPS actions', () {
    test('formats coordinates for copy', () {
      expect(formatLatLng(-38.9512344, -68.0598764), '-38.951234, -68.059876');
    });

    test('formats Google Maps link without raw JSON or source fields', () {
      final link = googleMapsSearchUrl(-38.9512344, -68.0598764);

      expect(
        link,
        'https://www.google.com/maps/search/?api=1&query=-38.951234,-68.059876',
      );
      expect(link, isNot(contains('source=current')));
      expect(link, isNot(contains('{')));
      expect(link, isNot(contains('}')));
    });

    test('formats precision as a professional label', () {
      expect(formatAccuracyMeters(12.4), 'Precisión: 12 m');
      expect(formatAccuracyMeters(null), isEmpty);
    });
  });
}
